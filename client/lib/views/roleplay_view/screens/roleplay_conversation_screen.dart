import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_router.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/live_voice_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/feedback_config.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/models/session_result_model.dart'
    show TurnTranscript, TurnAudioChunk, TurnDone, TurnStreamError;
import 'package:communiq/views/roleplay_view/screens/roleplay_feedback_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── State machine ─────────────────────────────────────────────────────────────
//
//  user_turn  ──[SEND]──▶  processing  ──[AI response]──▶  ai_speaking
//      ▲                                                         │
//      └──────────────────[AI finishes or INTERRUPT]─────────────┘
//
enum _ConvState { user_turn, processing, ai_speaking, ending }

/// Colab parity: opening plays once; after each turn the AI clip plays twice before mic.
enum _AiPlaybackStage { none, afterOpening, afterTurnFirstPlay, afterTurnReplay }

// ─── Screen ────────────────────────────────────────────────────────────────────

class RoleplayConversationScreen extends StatefulWidget {
  final RoleplayConfig config;

  /// Pass an empty string or omit to activate demo mode (no backend calls).
  final String sessionId;
  final bool isOnboarding;

  /// When supplied (from the learning path), the level is written to
  /// SharedPreferences as "completed" the moment the user ends the call so
  /// the learning view can fire the XP animation and unlock the next node.
  final int? levelId;

  const RoleplayConversationScreen({
    super.key,
    required this.config,
    this.sessionId = 'demo',
    this.isOnboarding = false,
    this.levelId,
  });

  @override
  State<RoleplayConversationScreen> createState() =>
      _RoleplayConversationScreenState();
}

class _RoleplayConversationScreenState
    extends State<RoleplayConversationScreen> with TickerProviderStateMixin {
  // ─── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _waveformController;

  // ─── Session state ────────────────────────────────────────────────────────────
  _ConvState _state = _ConvState.processing;
  final List<Map<String, String>> _conversationHistory = [];
  _AiPlaybackStage _aiPlaybackStage = _AiPlaybackStage.none;
  /// Last turn’s AI audio bytes (base64) — replayed once before the next mic (Colab).
  String? _lastAiAudioForReplay;

  /// Sentence clips still waiting to play, in order.
  ///
  /// The streamed turn delivers audio one sentence at a time, so playback
  /// starts on the first clip while the rest are still being synthesised.
  /// Clips must play strictly in order, and the player's "completed" event
  /// fires at the end of *each* clip — so a queue is needed to tell "this
  /// sentence finished" from "the whole reply finished".
  final List<String> _pendingClips = [];

  /// True while a streamed reply is playing, so the completed handler advances
  /// the queue instead of returning the mic to the user.
  bool _streamingPlayback = false;

  /// Set once the server has sent every sentence. Until then an empty queue
  /// means "waiting for more audio", not "the reply is over".
  bool _streamClipsComplete = false;

  // The text shown in the large conversation card and who is speaking.
  // Updated on every meaningful state change.
  String _cardText = '';
  int _cardAnimKey = 0; // increment to trigger AnimatedSwitcher

  Timer? _sessionTimer;
  int _secondsElapsed = 0;
  int _totalSpokenSeconds = 0;
  DateTime? _micStartTime;

  bool _isMuted = false;

  // ─── Amplitude (real waveform) ────────────────────────────────────────────────
  Timer? _amplitudeTimer;
  List<double> _barAmplitudes = List.filled(7, 0.15);

  // ─── Speech-to-text (live captions) ──────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  // Live partial transcript shown while the user speaks.
  String _liveTranscript = '';

  /// True when running without a real session (onboarding demo, no auth).
  bool get _isDemoMode =>
      widget.sessionId == 'demo' || widget.sessionId.isEmpty;

  /// Scripted AI lines for the demo "Introduce yourself" session.
  static const List<String> _demoReplies = [
    "Hi there! Great to meet you. Tell me a little about yourself — "
        "what do you do and what brings you here today?",
    "That's really interesting! It sounds like you have a great background. "
        "What would you say is the thing you're most excited about in your work or life right now?",
    "Love that! You're doing really well — you're coming across as warm, "
        "clear and engaging. One small tip: try to end with a question to keep the conversation flowing. "
        "Shall we wrap up the practice?",
  ];

  /// Total spoken seconds including the currently-running mic session.
  /// In live voice mode _stopMic() is never called mid-session, so
  /// _totalSpokenSeconds stays 0 — we add the elapsed time since mic start.
  int get _effectiveSpokenSeconds {
    if (_micStartTime == null) return _totalSpokenSeconds;
    return _totalSpokenSeconds +
        DateTime.now().difference(_micStartTime!).inSeconds;
  }

  /// End-call enabled after ≥ 10 s elapsed + not mid-processing.
  /// In live voice mode the session timer runs from first audio so
  /// _secondsElapsed is the right measure (not spoken seconds which
  /// don't increment while the AI is talking on a live call).
  bool get _canEndCall {
    if (_state == _ConvState.processing || _state == _ConvState.ending) {
      return false;
    }
    if (_isLiveVoiceActive) {
      return _secondsElapsed >= 10;
    }
    return _effectiveSpokenSeconds >= 10 && _state == _ConvState.user_turn;
  }

  // ─── Audio ────────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;
  final List<String> _tempFiles = [];

  // ─── CP2: Live voice (LiveKit WebRTC) ─────────────────────────────────────────
  // Created lazily when the user opts into live voice mode.
  // Null when using classic HTTP mode (press-Send, upload WAV).
  LiveVoiceService? _liveVoiceService;
  bool _isLiveVoiceActive = false;
  // True once a LiveKit connection has been *attempted* (success or fail).
  // Used to decide whether to show manual Send/Interrupt buttons:
  //   - attempted + succeeded (_isLiveVoiceActive=true)  → no buttons
  //   - attempted + failed    (_isLiveVoiceActive=false) → show buttons
  //   - not yet attempted                                 → show buttons
  bool _liveVoiceAttempted = false;
  StreamSubscription<dynamic>? _liveVoiceDataSub;

  /// Server said opening response included LiveKit — we connect after the HTTP opening audio finishes.
  bool _serverLiveVoiceEnabled = false;

  // ─── Karaoke transcript (live voice + HTTP mode) ──────────────────────────────
  // Text currently displayed while the AI speaks. Words are appended one by
  // one. When the word count would exceed _KARAOKE_MAX_WORDS, the display
  // resets and continues from the next word — teleprompter-style page turns.
  String _karaokeChunk = '';
  // Number of words currently in _karaokeChunk. Reset each page-turn.
  int _karaokeWordCount = 0;
  // Max words before a page-clear. At 19sp font, ~1.6 line height, on a
  // ~360px wide card: ~5-6 words per line × ~7 visible lines ≈ 40 words
  // before the text would overflow the card's visible area.
  static const int _karaokeMaxWords = 40;
  // Full text of what the user said last turn — shown while user_turn is active.
  String _lastUserTranscript = '';
  // Used to cancel an in-flight local karaoke stream when interrupted.
  bool _localKaraokeActive = false;

  // ─── Opening loading state ────────────────────────────────────────────────────
  // True while the very first HTTP opening call is in flight.
  // Used to show a contextual "connecting" message instead of a generic spinner.
  bool _isOpeningLoading = true;

  // ─── Init / Dispose ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    debugPrint('');
    debugPrint('🎙 [Conversation] ── Session started ────────────────');
    debugPrint('   sessionId:  ${widget.sessionId}');
    debugPrint('   scenario:   ${widget.config.scenarioTitle}');
    debugPrint('   persona:    ${widget.config.persona}');
    debugPrint('   difficulty: ${widget.config.difficulty}');
    debugPrint('   tone:       ${widget.config.tone}');
    debugPrint('   role:       ${widget.config.role}');
    debugPrint('   traits:     ${widget.config.traits}');
    if (widget.config.backstory.isNotEmpty) {
      debugPrint('   backstory:  ${widget.config.backstory}');
    }
    debugPrint('   demo mode:  $_isDemoMode');
    debugPrint('   onboarding: ${widget.isOnboarding}');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _initStt();
    // Timer is started lazily — see _startTimerIfNotStarted() called from
    // _playBase64Audio and _connectLiveVoice so it begins when audio/voice
    // actually starts, not when the screen loads.
    _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
    if (_isDemoMode) {
      _bootstrapDemoOpening();
    } else {
      _bootstrapRealOpening();
    }
  }

  @override
  void dispose() {
    debugPrint(
        '🎙 [Conversation] Screen disposed — session=${widget.sessionId}');
    _cancelLocalKaraoke();
    _sessionTimer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _stt.cancel();
    _liveVoiceDataSub?.cancel();
    _liveVoiceService?.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  // ─── CP2: Live voice helpers ──────────────────────────────────────────────────

  /// Connect to LiveKit for the current session.
  /// Falls back to classic HTTP mode silently if the server does not support it.
  Future<void> _connectLiveVoice() async {
    if (_isDemoMode || widget.sessionId.isEmpty) return;
    if (_isLiveVoiceActive) return;
    debugPrint('[LiveVoice] Attempting connection — session=${widget.sessionId}');
    try {
      final svc = LiveVoiceService(ApiService.instance.dio);
      await svc.connect(widget.sessionId);

      // Subscribe to real-time captions from the Pipecat bot.
      _liveVoiceDataSub = svc.messages.listen(_onLiveVoiceMessage);

      if (mounted) {
        setState(() {
          _liveVoiceService = svc;
          _isLiveVoiceActive = true;
          _liveVoiceAttempted = true;
        });
      }
      _startTimerIfNotStarted();
      debugPrint('[LiveVoice] ✅ Connected — live voice active, session=${widget.sessionId}');
    } on LiveVoiceException catch (e) {
      debugPrint('[LiveVoice] ⚠️ Connection failed — falling back to classic HTTP: $e');
      if (mounted) setState(() => _liveVoiceAttempted = true);
    } catch (e) {
      debugPrint('[LiveVoice] ❌ Unexpected error — falling back to classic HTTP: $e');
      if (mounted) setState(() => _liveVoiceAttempted = true);
    }
  }

  /// Handle real-time state messages from the Pipecat bot.
  ///
  ///  "user_transcript" → show what the user said; save to history.
  ///  "ai_transcript"   → full AI reply saved for evaluation; karaoke started.
  ///  "ai_karaoke"      → replace karaoke display with the next word-chunk.
  ///  "ai_done"         → switch back to user_turn so the user can speak again.
  void _onLiveVoiceMessage(LiveVoiceMessage msg) {
    if (!mounted) return;
    switch (msg.type) {
      case 'user_transcript':
        if (msg.text.isEmpty) return;
        _conversationHistory.add({'role': 'user', 'transcript': msg.text});
        setState(() {
          _lastUserTranscript = msg.text;
          _karaokeChunk = '';
          _karaokeWordCount = 0;
        });
        debugPrint('[LiveVoice] User said: "${msg.text}"');

      case 'ai_transcript':
        if (msg.text.isEmpty) return;
        // Full text — saved for evaluation; karaoke chunks handle the display.
        _conversationHistory.add({'role': 'ai', 'transcript': msg.text});
        setState(() {
          _state = _ConvState.ai_speaking;
          _karaokeChunk = '';
          _karaokeWordCount = 0;
          _cardAnimKey++;
        });
        debugPrint('[LiveVoice] AI says: "${msg.text.length > 60 ? '${msg.text.substring(0, 60)}…' : msg.text}"');

      case 'ai_karaoke':
        // Single word from the bot — accumulate into the display buffer.
        // When the buffer exceeds the max word count, clear and start fresh
        // so the text never overflows the card (teleprompter page-turn).
        if (msg.text.isEmpty) return;
        final incomingWords = msg.text.trim().split(RegExp(r'\s+'));
        setState(() {
          for (final word in incomingWords) {
            if (_karaokeWordCount >= _karaokeMaxWords) {
              _karaokeChunk = word;
              _karaokeWordCount = 1;
            } else {
              _karaokeChunk = _karaokeChunk.isEmpty ? word : '$_karaokeChunk $word';
              _karaokeWordCount++;
            }
          }
        });

      case 'ai_done':
        setState(() {
          _state = _ConvState.user_turn;
          _karaokeChunk = '';
          _karaokeWordCount = 0;
          _lastUserTranscript = '';
          _cardAnimKey++;
        });
        debugPrint('[LiveVoice] AI finished speaking — user turn');

      default:
        debugPrint('[LiveVoice] Unknown data message type: ${msg.type}');
    }
  }

  /// Stream text locally word-by-word (for HTTP opening / HTTP fallback turns).
  ///
  /// Sends one word every ~0.40 s, accumulating into [_karaokeChunk].
  /// When [_karaokeMaxWords] is reached the display clears and continues
  /// from the next word — same teleprompter page-turn as live voice mode.
  ///
  /// Call [_cancelLocalKaraoke] first if a previous stream may still be running.
  Future<void> _streamLocalKaraoke(String text) async {
    _localKaraokeActive = true;
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) { _localKaraokeActive = false; return; }
    const delay = Duration(milliseconds: 400); // ~0.40 s per word

    for (int i = 0; i < words.length; i++) {
      if (!_localKaraokeActive || !mounted) break;
      final word = words[i];
      setState(() {
        if (_karaokeWordCount >= _karaokeMaxWords) {
          _karaokeChunk = word;
          _karaokeWordCount = 1;
        } else {
          _karaokeChunk = _karaokeChunk.isEmpty ? word : '$_karaokeChunk $word';
          _karaokeWordCount++;
        }
      });
      // Don't delay after the last word.
      if (i < words.length - 1) {
        await Future.delayed(delay);
      }
    }
    _localKaraokeActive = false;
  }

  void _cancelLocalKaraoke() {
    _localKaraokeActive = false;
  }

  /// Disconnect from LiveKit at session end or on dispose.
  Future<void> _disconnectLiveVoice() async {
    if (!_isLiveVoiceActive) return;
    await _liveVoiceDataSub?.cancel();
    _liveVoiceDataSub = null;
    await _liveVoiceService?.disconnect();
    if (mounted) {
      setState(() {
        _isLiveVoiceActive = false;
      });
    }
  }

  // ─── Speech-to-text ───────────────────────────────────────────────────────────

  Future<void> _initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (err) =>
            debugPrint('[STT] Error: ${err.errorMsg}'),
        onStatus: (status) =>
            debugPrint('[STT] Status: $status'),
      );
      debugPrint('[STT] Available: $_sttAvailable');
    } catch (e) {
      debugPrint('[STT] Init failed: $e');
      _sttAvailable = false;
    }
  }

  Future<void> _startSttListening() async {
    if (!_sttAvailable) return;
    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted || _state != _ConvState.user_turn) return;
          setState(() {
            _liveTranscript = result.recognizedWords;
          });
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 15),
        partialResults: true,
        localeId: 'en_IN',
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('[STT] Listen failed (graceful): $e');
    }
  }

  void _stopSttListening() {
    if (_sttAvailable) {
      _stt.stop();
    }
  }

  int get _completedUserTurns =>
      _conversationHistory.where((m) => m['role'] == 'user').length;

  /// Demo: scripted opener on card, then mic (no backend, no Colab replay).
  void _bootstrapDemoOpening() {
    setState(() {
      _state = _ConvState.processing;
      _cardText = '';
      _cardAnimKey++;
    });
    Future<void>.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final opener = _demoReplies.first;
      _conversationHistory.add({'role': 'ai', 'transcript': opener});
      setState(() {
        _state = _ConvState.ai_speaking;
        _cardText = opener;
        _cardAnimKey++;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      _aiPlaybackStage = _AiPlaybackStage.none;
      await _startMic();
    });
  }

  void _bootstrapRealOpening() {
    Future<void>.microtask(() async {
      debugPrint('🔄 [Conversation] Fetching AI opening...');
      final sw = Stopwatch()..start();
      try {
        final opening = await SessionService.instance
            .fetchOpening(sessionId: widget.sessionId);
        sw.stop();
        if (!mounted) return;

        debugPrint('✅ [Conversation] Opening received in ${sw.elapsedMilliseconds}ms');
        debugPrint('   aiReply:         "${opening.aiReply.length > 80 ? '${opening.aiReply.substring(0, 80)}...' : opening.aiReply}"');
        debugPrint('   audio size:      ${(opening.aiAudioBase64.length * 3 / 4).round()} bytes (base64)');
        debugPrint('   liveVoiceEnabled: ${opening.liveVoiceEnabled}');

        _serverLiveVoiceEnabled = opening.liveVoiceEnabled;
        _conversationHistory.add({
          'role': 'ai',
          'transcript': opening.aiReply,
        });
        setState(() {
          _isOpeningLoading = false;
          _state = _ConvState.ai_speaking;
          _cardText = opening.aiReply; // kept for history; karaoke drives display
          _karaokeChunk = '';
          _karaokeWordCount = 0;
          _cardAnimKey++;
        });
        _aiPlaybackStage = _AiPlaybackStage.afterOpening;
        // Stream karaoke chunks concurrently with audio playback so text
        // appears in sync with the voice, just like the live voice mode.
        await Future.wait([
          _playBase64Audio(opening.aiAudioBase64),
          _streamLocalKaraoke(opening.aiReply),
        ]);
      } catch (e) {
        sw.stop();
        debugPrint('❌ [Conversation] Opening failed after ${sw.elapsedMilliseconds}ms: $e');
        if (!mounted) return;
        setState(() => _isOpeningLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e.toString())),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
            duration: const Duration(seconds: 4),
          ),
        );
        _aiPlaybackStage = _AiPlaybackStage.none;
        await _startMic();
      }
    });
  }

  // ─── Timer ────────────────────────────────────────────────────────────────────

  int? get _timeLimitSeconds {
    switch (widget.config.timeLimit) {
      case '30 sec':
        return 30;
      case '60 sec':
        return 60;
      case '2 min':
        return 120;
      default:
        return null;
    }
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsElapsed++);
      final limit = _timeLimitSeconds;
      if (limit != null &&
          _secondsElapsed >= limit &&
          _state == _ConvState.user_turn) {
        debugPrint(
            '⏱ [Conversation] Time limit reached — auto-ending session');
        _endSession(force: true);
      }
    });
  }

  /// Called the first time real audio/voice activity starts.
  /// Ensures the timer only counts time the user is actually in the session,
  /// not the loading/connection delay before the first word is spoken.
  void _startTimerIfNotStarted() {
    if (_sessionTimer != null) return;
    debugPrint('⏱ [Conversation] Timer started — first audio/voice activity');
    _startTimer();
  }

  String get _formattedTime {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int? get _secondsRemaining {
    final limit = _timeLimitSeconds;
    if (limit == null) return null;
    return math.max(0, limit - _secondsElapsed);
  }

  // ─── Mic management ───────────────────────────────────────────────────────────

  Future<void> _startMic() async {
    if (!mounted) return;
    debugPrint('🎙 [Conversation] Starting mic...');
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('❌ [Conversation] Mic permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    // LiveKit is already publishing the mic — do not start the file recorder
    // (Android: record + WebRTC mic together breaks audio focus).
    if (_isLiveVoiceActive) {
      _cancelLocalKaraoke();
      _micStartTime = DateTime.now();
      _liveTranscript = '';
      if (!mounted) return;
      setState(() {
        _state = _ConvState.user_turn;
        _cardText = '';
        _karaokeChunk = '';
        _karaokeWordCount = 0;
        _cardAnimKey++;
      });
      _pulseController.duration = const Duration(milliseconds: 800);
      _pulseController.repeat(reverse: true);
      debugPrint('🎙 [Conversation] Live voice user turn (no file recorder)');
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/turn_${DateTime.now().millisecondsSinceEpoch}.wav';
    _tempFiles.add(_recordingPath!);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    _micStartTime = DateTime.now();
    debugPrint('✅ [Conversation] Mic active — user turn #${_completedUserTurns + 1}, '
        'recording to ${_recordingPath!.split('/').last}');

    // NOTE: speech_to_text and the `record` package both compete for Android's
    // audio focus (RECORD_AUDIO). Running them simultaneously causes the recorder
    // to lose focus (onAudioFocusChange(-2)), producing corrupted or silent audio.
    // STT is therefore only started AFTER the recorder has finished (see _onSend).
    _liveTranscript = '';

    // Poll mic amplitude every 80 ms.
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!mounted) return;
      try {
        final amp = await _recorder.getAmplitude();
        final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
        if (mounted) {
          setState(() {
            _barAmplitudes = [..._barAmplitudes.sublist(1), normalized];
          });
        }
      } catch (_) {}
    });

    if (!mounted) return;
    setState(() {
      _state = _ConvState.user_turn;
      _cardText = '';
      _cardAnimKey++;
    });
    _pulseController.duration = const Duration(milliseconds: 800);
    _pulseController.repeat(reverse: true);
  }

  void _stopMic() {
    _stopSttListening();
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _barAmplitudes = List.filled(7, 0.15);

    if (_micStartTime != null) {
      final spokenSecs =
          DateTime.now().difference(_micStartTime!).inSeconds;
      _totalSpokenSeconds += spokenSecs;
      debugPrint(
          '🎙 [Conversation] Mic stopped — spoke ${spokenSecs}s this turn, '
          'total ${_totalSpokenSeconds}s spoken');
      _micStartTime = null;
    }
    _pulseController.duration = const Duration(seconds: 2);
    _pulseController.repeat(reverse: true);
  }

  // ─── SEND ─────────────────────────────────────────────────────────────────────

  Future<void> _onSend() async {
    if (_state != _ConvState.user_turn) return;

    if (_isLiveVoiceActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live mode: you are talking to the AI over the network. '
            'Tap End call when you are done.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    debugPrint('📤 [Conversation] SEND pressed — stopping recording...');
    _stopMic();

    final path = await _recorder.stop();

    if (!mounted) return;
    setState(() {
      _state = _ConvState.processing;
      _cardText = '';
      _cardAnimKey++;
    });

    if (path == null) {
      debugPrint('❌ [Conversation] Recording path is null — mic failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording failed — please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      await _startMic();
      return;
    }

    final fileSize = await File(path).length();
    debugPrint(
        '📤 [Conversation] Sending audio: ${path.split('/').last} (${fileSize}B)');

    // 16 kHz · 16-bit · mono WAV = 32 000 bytes/s + 44-byte header.
    // Anything under ~1 s is too short for Whisper to transcribe reliably.
    const _minAudioBytes = 32044; // ≈ 1 second
    if (fileSize < _minAudioBytes) {
      debugPrint('⚠️  [Conversation] Audio too short (${fileSize}B) — asking user to speak more');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too short — please speak for at least 1 second, then tap SEND.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _startMic();
      return;
    }

    await _sendTurn(path);
  }

  // ─── INTERRUPT ────────────────────────────────────────────────────────────────

  Future<void> _onInterrupt() async {
    if (_state != _ConvState.ai_speaking) return;
    debugPrint('✋ [Conversation] INTERRUPT — stopping AI audio');
    HapticFeedback.lightImpact();
    _aiPlaybackStage = _AiPlaybackStage.none;
    await _audioPlayer.stop();
    await _startMic();
  }

  // ─── API: process turn ────────────────────────────────────────────────────────

  /// Peak sample amplitude of a 16-bit PCM WAV, as a 0..1 fraction.
  ///
  /// A muted or unrouted microphone still produces a perfectly well-formed
  /// recording of the right length — it is simply full of near-zero samples.
  /// Without this check the app happily uploads 30 seconds of silence, gets an
  /// empty transcript back, and shows the user nothing at all.
  double _peakAmplitude(Uint8List wav) {
    const headerBytes = 44; // canonical PCM WAV header
    if (wav.length <= headerBytes + 1) return 0;
    var peak = 0;
    // Step over samples rather than reading every one — a few thousand points
    // is plenty to tell speech from a noise floor, and this runs on the UI
    // isolate right before an upload.
    final stride = ((wav.length - headerBytes) ~/ 2 ~/ 4000).clamp(1, 1 << 20) * 2;
    for (var i = headerBytes; i + 1 < wav.length; i += stride) {
      var v = wav[i] | (wav[i + 1] << 8);
      if (v >= 0x8000) v -= 0x10000; // little-endian signed 16-bit
      final a = v.abs();
      if (a > peak) peak = a;
    }
    return peak / 32768.0;
  }

  /// Below this the recording carries no speech — measured at 0.02% on a
  /// microphone that was delivering nothing but its own noise floor, against
  /// several percent for even quiet talking.
  static const double _silenceThreshold = 0.02;

  /// Hands the turn back to the user without consuming it.
  Future<void> _rejectSilentTurn(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() {
      _liveTranscript = '';
      _cardText = '';
      _cardAnimKey++;
    });
    _aiPlaybackStage = _AiPlaybackStage.none;
    await _startMic();
  }

  /// Plays the next queued sentence, or finishes the reply if there are none
  /// left and the server has said it is done.
  Future<void> _playNextClip() async {
    if (_pendingClips.isEmpty) {
      if (_streamClipsComplete) {
        _streamingPlayback = false;
        _aiPlaybackStage = _AiPlaybackStage.none;
        _audioFinishHandled = false;
        await _onAudioFinished();
      }
      // Otherwise: more sentences are still being synthesised. The next
      // arrival will call back into here.
      return;
    }
    final path = _pendingClips.removeAt(0);
    try {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ [Conversation] Clip playback failed: $e');
      await _playNextClip(); // skip the bad clip rather than stall the reply
    }
  }

  /// A streamed turn: transcript first, then audio a sentence at a time.
  ///
  /// The batch endpoint could not respond until the last sentence had been
  /// synthesised, which was the bulk of the wait between speaking and hearing
  /// a reply. Here the transcript is on screen in about half a second and the
  /// first sentence starts playing while the rest are still being made.
  Future<void> _sendTurnStreamed(String audioPath, int turnNumber) async {
    final bytes = await File(audioPath).readAsBytes();
    final filename = audioPath.split(Platform.pathSeparator).last;
    final sw = Stopwatch()..start();

    _pendingClips.clear();
    _streamClipsComplete = false;
    _streamingPlayback = true;
    var clipCount = 0;
    var sawTranscript = false;

    final stream = SessionService.instance.processTurnStreamed(
      sessionId: widget.sessionId,
      audioBytes: Uint8List.fromList(bytes),
      filename: filename,
      conversationHistory: List.from(_conversationHistory),
    );

    await for (final event in stream) {
      if (!mounted) return;
      switch (event) {
        case TurnTranscript(:final userTranscript, :final aiReply):
          sawTranscript = true;
          debugPrint('📝 [Conversation] Transcript in '
              '${sw.elapsedMilliseconds}ms — "$userTranscript"');

          if (userTranscript.trim().isEmpty) {
            _streamingPlayback = false;
            await _rejectSilentTurn(
              "I didn't catch that. Speak a little louder, or check your mic.",
            );
            return;
          }

          _conversationHistory.addAll([
            {'role': 'user', 'transcript': userTranscript},
            {'role': 'ai', 'transcript': aiReply},
          ]);

          setState(() {
            _state = _ConvState.ai_speaking;
            _cardText = aiReply;
            _karaokeChunk = '';
            _karaokeWordCount = 0;
            _cardAnimKey++;
            _liveTranscript = '';
          });
          _startTimerIfNotStarted();
          // Karaoke runs alongside playback rather than gating it.
          unawaited(_streamLocalKaraoke(aiReply));

        case TurnAudioChunk(:final index, :final audioBase64):
          if (audioBase64.isEmpty) continue;
          final dir = await getTemporaryDirectory();
          final path =
              '${dir.path}/ai_${DateTime.now().millisecondsSinceEpoch}_$index.mp3';
          _tempFiles.add(path);
          await File(path).writeAsBytes(base64Decode(audioBase64));
          _pendingClips.add(path);
          clipCount++;

          if (clipCount == 1) {
            debugPrint('🔊 [Conversation] First audio in '
                '${sw.elapsedMilliseconds}ms — starting playback');
            _audioFinishHandled = false;
            await _playNextClip();
          } else if (_audioPlayer.playing != true &&
              _pendingClips.isNotEmpty) {
            // Synthesis fell behind playback; resume as soon as it catches up.
            await _playNextClip();
          }

        case TurnDone():
          _streamClipsComplete = true;
          debugPrint('✅ [Conversation] Turn #$turnNumber streamed in '
              '${sw.elapsedMilliseconds}ms ($clipCount clips)');
          if (_pendingClips.isEmpty && _audioPlayer.playing != true) {
            await _playNextClip();
          }

        case TurnStreamError(:final detail):
          _streamingPlayback = false;
          _streamClipsComplete = true;
          throw Exception(detail);
      }
    }

    if (!sawTranscript) {
      _streamingPlayback = false;
      throw Exception('The turn ended before the AI replied.');
    }
    // A stream that closes without a done marker still has to release the mic.
    _streamClipsComplete = true;
    if (_pendingClips.isEmpty && _audioPlayer.playing != true) {
      await _playNextClip();
    }
  }

  Future<void> _sendTurn(String audioPath) async {
    final turnNumber = _completedUserTurns + 1;
    debugPrint('🔄 [Conversation] Processing turn #$turnNumber...');

    // ── Demo mode ──────────────────────────────────────────────────────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final fakeUserTranscript =
          'Great to be here — let me tell you a bit about myself.';
      final replyIndex =
          (_completedUserTurns + 1).clamp(0, _demoReplies.length - 1);
      final aiReply = _demoReplies[replyIndex];

      _conversationHistory.addAll([
        {'role': 'user', 'transcript': fakeUserTranscript},
        {'role': 'ai', 'transcript': aiReply},
      ]);

      // Briefly show what "you said"
      setState(() {
        _state = _ConvState.user_turn;
        _cardText = fakeUserTranscript;
        _cardAnimKey++;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() {
        _state = _ConvState.ai_speaking;
        _cardText = aiReply;
        _cardAnimKey++;
      });
      _aiPlaybackStage = _AiPlaybackStage.none;
      await _onAudioFinished();
      return;
    }

    // ── Real mode ──────────────────────────────────────────────────────────────
    try {
      // Streamed: the transcript lands in ~0.5s and the first sentence starts
      // playing while the rest are still being synthesised. The batch call
      // below is kept as the fallback for a server without the stream route.
      final probe = await File(audioPath).readAsBytes();
      final probePeak = _peakAmplitude(probe);
      debugPrint('📊 [Conversation] Recording peak amplitude: '
          '${(probePeak * 100).toStringAsFixed(3)}%');
      if (probePeak < _silenceThreshold) {
        debugPrint('🔇 [Conversation] Turn #$turnNumber is silent — not sending');
        setState(() => _state = _ConvState.user_turn);
        await _rejectSilentTurn(
          "I couldn't hear anything — check your microphone and try again.",
        );
        return;
      }

      try {
        await _sendTurnStreamed(audioPath, turnNumber);
        return;
      } catch (e) {
        _streamingPlayback = false;
        _pendingClips.clear();
        debugPrint('⚠️ [Conversation] Streamed turn failed, '
            'falling back to batch: $e');
      }

      final bytes = await File(audioPath).readAsBytes();
      final filename = audioPath.split(Platform.pathSeparator).last;

      debugPrint('📤 [Conversation] Turn #$turnNumber → ${bytes.length}B audio, '
          'history=${_conversationHistory.length} turns');
      final sw = Stopwatch()..start();

      final result = await SessionService.instance.processTurn(
        sessionId: widget.sessionId,
        audioBytes: Uint8List.fromList(bytes),
        filename: filename,
        conversationHistory: List.from(_conversationHistory),
      );
      sw.stop();

      // The server heard nothing. Previously this fell straight through: an
      // empty user turn was appended to the history, the AI replied to it, and
      // the user was given no clue that their voice never arrived. That is
      // exactly what "it is not taking my voice input" looks like.
      if (result.userTranscript.trim().isEmpty) {
        debugPrint('🔇 [Conversation] Turn #$turnNumber — empty transcript');
        await _rejectSilentTurn(
          "I didn't catch that. Speak a little louder, or check your mic.",
        );
        return;
      }

      _conversationHistory.addAll([
        {'role': 'user', 'transcript': result.userTranscript},
        {'role': 'ai', 'transcript': result.aiReply},
      ]);

      debugPrint('✅ [Conversation] Turn #$turnNumber complete in ${sw.elapsedMilliseconds}ms');
      debugPrint('   User: "${result.userTranscript}"');
      debugPrint(
          '   AI:   "${result.aiReply.length > 80 ? '${result.aiReply.substring(0, 80)}...' : result.aiReply}"');
      debugPrint('   audio: ${(result.aiAudioBase64.length * 3 / 4).round()} bytes, turnCount=${result.turnCount}');

      if (!mounted) return;

      // Briefly surface what the STT engine understood.
      if (result.userTranscript.isNotEmpty) {
        setState(() {
          _state = _ConvState.user_turn;
          _cardText = result.userTranscript;
          _cardAnimKey++;
          _liveTranscript = '';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;
      }

      setState(() {
        _state = _ConvState.ai_speaking;
        _cardText = result.aiReply; // kept for history; karaoke drives display
        _karaokeChunk = '';
        _karaokeWordCount = 0;
        _cardAnimKey++;
      });

      _lastAiAudioForReplay = result.aiAudioBase64;
      _aiPlaybackStage = _AiPlaybackStage.afterTurnFirstPlay;
      // Stream karaoke concurrent with audio so text appears in sync.
      await Future.wait([
        _playBase64Audio(result.aiAudioBase64),
        _streamLocalKaraoke(result.aiReply),
      ]);
    } catch (e) {
      debugPrint('❌ [Conversation] Turn #$turnNumber failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _liveTranscript = '';
        _cardText = '';
        _cardAnimKey++;
      });
      await _startMic();
    }
  }

  // ─── Audio playback ───────────────────────────────────────────────────────────

  Future<void> _playBase64Audio(String base64Audio) async {
    if (base64Audio.isEmpty) {
      debugPrint('🔇 [Conversation] No AI audio returned — skipping playback');
      _audioFinishHandled = false;
      _startTimerIfNotStarted();
      await _onAudioFinished();
      return;
    }
    if (_isMuted) {
      debugPrint('🔇 [Conversation] Muted — skipping AI audio playback');
      _audioFinishHandled = false;
      _startTimerIfNotStarted();
      await _onAudioFinished();
      return;
    }
    // Timer starts the moment the first audio byte plays.
    _startTimerIfNotStarted();
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/ai_reply_${DateTime.now().millisecondsSinceEpoch}.mp3';
      _tempFiles.add(filePath);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      debugPrint(
          '🔊 [Conversation] Playing AI audio (${bytes.length}B)...');
      _audioFinishHandled = false;
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ [Conversation] Audio playback failed: $e');
      await _onAudioFinished();
    }
  }

  /// Guards [_onAudioFinished] against running twice for one clip.
  ///
  /// The player's completed event can fire more than once, and the method is
  /// also invoked directly on the error paths. A second run re-entered
  /// _startMic after live voice had connected, flipping the mic into the
  /// no-file-recorder branch and silently ending the conversation.
  bool _audioFinishHandled = false;

  void _onPlayerStateChange(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (_state != _ConvState.ai_speaking) return;
      // A streamed reply is many clips. "completed" here means this sentence
      // ended, not the reply — advance the queue and only finish when the
      // server has sent everything and nothing is left to play.
      if (_streamingPlayback) {
        unawaited(_playNextClip());
        return;
      }
      debugPrint(
          '🔊 [Conversation] AI audio finished — returning mic to user');
      _onAudioFinished();
    }
  }

  Future<void> _onAudioFinished() async {
    if (!mounted) return;
    if (_audioFinishHandled) {
      debugPrint('🔊 [Conversation] Ignoring duplicate audio-finished event');
      return;
    }
    _audioFinishHandled = true;
    switch (_aiPlaybackStage) {
      case _AiPlaybackStage.afterOpening:
        _aiPlaybackStage = _AiPlaybackStage.none;
        if (_serverLiveVoiceEnabled) {
          await _connectLiveVoice();
        }
        await _startMic();
        return;
      case _AiPlaybackStage.afterTurnFirstPlay:
        final b64 = _lastAiAudioForReplay;
        if (b64 == null || b64.isEmpty || _isMuted) {
          _aiPlaybackStage = _AiPlaybackStage.none;
          await _startMic();
          return;
        }
        _aiPlaybackStage = _AiPlaybackStage.afterTurnReplay;
        await _playBase64Audio(b64);
        return;
      case _AiPlaybackStage.afterTurnReplay:
        _aiPlaybackStage = _AiPlaybackStage.none;
        await _startMic();
        return;
      case _AiPlaybackStage.none:
        await _startMic();
        return;
    }
  }

  // ─── Mute ─────────────────────────────────────────────────────────────────────

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);
    debugPrint(
        '🔇 [Conversation] Mute toggled → ${_isMuted ? "MUTED" : "unmuted"}');
    if (_isMuted && _state == _ConvState.ai_speaking) {
      _audioPlayer.stop();
      _onAudioFinished();
    }
  }

  // ─── End session ──────────────────────────────────────────────────────────────

  Future<void> _endSession({bool force = false}) async {
    if (!force && !_canEndCall) return;
    HapticFeedback.heavyImpact();

    await _disconnectLiveVoice();

    debugPrint('');
    debugPrint('🏁 [Conversation] Ending session ─────────────────────');
    debugPrint('   sessionId:    ${widget.sessionId}');
    debugPrint('   user turns:   $_completedUserTurns');
    debugPrint('   total time:   ${_secondsElapsed}s');
    debugPrint('   spoken time:  ${_totalSpokenSeconds}s');

    _stopMic();
    await _recorder.stop();
    _sessionTimer?.cancel();
    _streamingPlayback = false;
    _pendingClips.clear();

    // ── Mark level complete in SharedPreferences ───────────────────────────────
    // This fires before any async AI call so the learning view always receives
    // a completion signal when it reads prefs on return, even if the AI fails.
    await _markLevelComplete();

    setState(() {
      _state = _ConvState.ending;
      _cardText = '';
      _cardAnimKey++;
    });

    // ── Demo mode ──────────────────────────────────────────────────────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.roleplayFeedback,
        extra: FeedbackArgs(
            config: FeedbackConfig(
              scenarioTitle: widget.config.scenarioTitle.isNotEmpty
                  ? widget.config.scenarioTitle
                  : 'Introduce Yourself',
              overallScore: 78,
              skills: const [
                SkillCard(
                    title: 'Clarity & Fluency',
                    score: 82,
                    tags: ['Clear', 'Natural']),
                SkillCard(
                    title: 'Confidence',
                    score: 74,
                    tags: ['Developing', 'Growing']),
                SkillCard(
                    title: 'Vocabulary & Grammar',
                    score: 79,
                    tags: ['Solid', 'Good']),
                SkillCard(
                    title: 'Pronunciation',
                    score: 76,
                    tags: ['Good', 'Solid']),
              ],
              insights: const [
                'You came across as warm and approachable — great first impression.',
                'Your introduction had a clear structure. Keep building on that.',
                'No major filler words detected — clean, direct speech.',
              ],
              improvements: const [
                'End with a question to invite the other person to share.',
                'Vary your sentence length for a more dynamic delivery.',
                'Add one specific detail about your work to make it memorable.',
              ],
            ),
            conversationHistory: _conversationHistory.isNotEmpty
                ? List.from(_conversationHistory)
                : const [
                    {'role': 'ai', 'transcript': 'Hello! I\'m glad we could meet today. What brings you in?'},
                    {'role': 'user', 'transcript': 'I want to di-ve-lop my negoshiation skills.'},
                    {'role': 'ai', 'transcript': 'That\'s a great goal. Let\'s start with the basics.'},
                  ],
            isOnboarding: widget.isOnboarding,
            xpAwarded: 50,
            newLevel: 1,
            leveledUp: false,
            newBadges: const [],
            newStreak: 1,
        ),
      );
      return;
    }

    // ── Real mode ──────────────────────────────────────────────────────────────
    try {
      debugPrint(
          '⏳ [Conversation] Requesting AI evaluation (may take up to 90s)...');
      final result =
          await SessionService.instance.endSession(widget.sessionId);
      final feedbackConfig =
          result.report.toFeedbackConfig(widget.config.scenarioTitle);

      debugPrint('✅ [Conversation] Evaluation received');
      if (!mounted) return;
      // Must go through go_router. This screen is a page-based route, so an
      // imperative pushReplacement threw "A page-based route cannot be
      // completed using imperative api" — *after* the AI evaluation had
      // already completed. The report was generated and stored, and the user
      // never saw it, which is why evaluation looked broken.
      context.pushReplacement(
        AppRoutes.roleplayFeedback,
        extra: FeedbackArgs(
          config: feedbackConfig,
          report: result.report,
          conversationHistory: List.from(_conversationHistory),
          isOnboarding: widget.isOnboarding,
          xpAwarded: result.xpAwarded,
          newLevel: result.newLevel,
          leveledUp: result.leveledUp,
          newBadges: result.newBadges,
          newStreak: result.newStreak,
        ),
      );
    } catch (e) {
      debugPrint('❌ [Conversation] endSession failed: $e');
      if (!mounted) return;

      final errStr = e.toString();

      // The server already abandoned the session (no turns) or it is no longer
      // active — retrying will always 400, so navigate back cleanly.
      if (errStr.contains('No turns recorded') ||
          errStr.contains('not in progress') ||
          errStr.contains('abandoned')) {
        debugPrint(
            '⚠️  [Conversation] Session already closed server-side — navigating back');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session ended — no turns were completed.'),
              duration: Duration(seconds: 3),
            ),
          );
          context.pop();
        }
        return;
      }

      // Transient error — let the user retry.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate feedback — please try again.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() {
        _cardText = '';
        _cardAnimKey++;
      });
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secondsElapsed++);
      });
      await _startMic();
    }
  }

  // ─── Mark level complete (SharedPreferences) ──────────────────────────────

  /// Saves [widget.levelId] into the 'completed_level_ids' SharedPreferences
  /// list so the learning view can detect completion on return and fire the
  /// XP flying animation plus unlock the next node.
  Future<void> _markLevelComplete() async {
    final id = widget.levelId;
    if (id == null) return; // not launched from the learning path
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = (prefs.getStringList('completed_level_ids') ?? []).toSet();
      existing.add(id.toString());
      await prefs.setStringList('completed_level_ids', existing.toList());
      debugPrint('✅ [LevelComplete] Level $id saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ [LevelComplete] Failed to save level $id: $e');
    }
  }

  // ─── Back / abandon session ───────────────────────────────────────────────────

  Future<void> _onWillPop() async {
    debugPrint('⚠️  [Conversation] Back pressed — showing abandon dialog');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Session?',
            style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold)),
        content: const Text(
            'Leaving now will abandon this session. Progress will not be saved.',
            style: TextStyle(color: AppColors.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay',
                style: TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      debugPrint(
          '🗑  [Conversation] User chose to abandon — '
          'user turns completed: $_completedUserTurns, '
          'time: ${_secondsElapsed}s');
      _sessionTimer?.cancel();
      await _disconnectLiveVoice();
      await _recorder.stop();
      await _audioPlayer.stop();
      SessionService.instance.abandonSession(widget.sessionId).ignore();
      _cleanupTempFiles();
      // context.pop, not Navigator.pop: this screen is a go_router page, and
      // completing it imperatively throws. Abandoning a session used to fail
      // on the way out for the same reason ending one did.
      if (mounted) context.pop();
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────────

  void _cleanupTempFiles() {
    for (final path in _tempFiles) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _tempFiles.clear();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('Network') ||
        raw.contains('reach the server')) {
      return 'Cannot reach the server. Check your connection.';
    }
    if (raw.contains('unavailable') || raw.contains('503')) {
      return 'AI service unavailable — please try again.';
    }
    if (raw.contains('timed out') || raw.contains('timeout')) {
      return 'Request timed out — please try again.';
    }
    // 422 = audio too short / empty transcript from Whisper
    if (raw.contains('too short') || raw.contains('empty transcript') ||
        raw.contains('too small') || raw.contains('422')) {
      return 'Audio too short or unclear — please speak more clearly.';
    }
    // The AI server returned a speech recognition or LLM error
    if (raw.contains('Speech recognition') || raw.contains('AI response') ||
        raw.contains('Voice synthesis')) {
      return raw; // already a user-friendly message from FastAPI
    }
    return 'Something went wrong — please try again.';
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            _buildAmbientGlow(),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildOrb(),
                  const SizedBox(height: 16),
                  // Conversation card is the hero — takes all remaining space.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16),
                      child: _buildConversationCard(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ambient glow ─────────────────────────────────────────────────────────────

  Widget _buildAmbientGlow() {
    // Removed — no ambient glow blobs or bright effects.
    return const SizedBox.shrink();
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSunk,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.ink, size: 16),
            ),
            onPressed: _onWillPop,
            padding: EdgeInsets.zero,
          ),
          Column(
            children: [
              Text(
                widget.config.persona,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.brandLight.withValues(
                            alpha: 0.5 + 0.5 * _pulseController.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE SESSION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.brandLight,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
            ],
          ),
          _buildTimerPill(),
        ],
      ),
    );
  }

  Widget _buildTimerPill() {
    final remaining = _secondsRemaining;
    Color pillBg = AppColors.bgSunk;
    Color pillBorder = AppColors.outline;
    Color textColor = AppColors.ink;

    if (remaining != null) {
      if (remaining <= 10) {
        pillBg = Colors.redAccent.withValues(alpha: 0.15);
        pillBorder = Colors.redAccent;
        textColor = Colors.redAccent;
      } else if (remaining <= 30) {
        pillBg = Colors.orange.withValues(alpha: 0.12);
        pillBorder = Colors.orange;
        textColor = Colors.orange;
      }
    }

    final displayText = remaining != null
        ? '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}'
        : _formattedTime;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pillBorder),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Animated dots loader ─────────────────────────────────────────────────────
  Widget _buildDotsLoader({Color color = AppColors.brand, double size = 9}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) {
            final phase = (_pulseController.value + i / 3.0) % 1.0;
            final t = math.sin(phase * math.pi);
            return Container(
              width: size,
              height: size,
              margin: EdgeInsets.symmetric(horizontal: size * 0.3),
              transform: Matrix4.translationValues(0, -t * size * 0.8, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.4 + 0.6 * t),
              ),
            );
          },
        );
      }),
    );
  }

  // ─── Orb (compact) ────────────────────────────────────────────────────────────

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        double scale = 1.0 + (pulse * 0.06);

        Color orbColor;
        Color glowColor;

        if (_isLiveVoiceActive) {
          // In live voice mode the mic is ALWAYS on.
          // Orb is green/active regardless of who is speaking —
          // dimmed slightly when AI is speaking to hint whose turn it is.
          switch (_state) {
            case _ConvState.user_turn:
              orbColor = AppColors.brand;
              glowColor = AppColors.brandLight;
              scale = 1.0 + (pulse * 0.14); // more pulse = user is expected to speak
            case _ConvState.ai_speaking:
              // Mic still on — just dim the orb so the AI's side feels dominant.
              orbColor = AppColors.brand.withValues(alpha: 0.45);
              glowColor = AppColors.brandLight.withValues(alpha: 0.3);
              scale = 1.0 + (pulse * 0.04);
            case _ConvState.processing:
            case _ConvState.ending:
              orbColor = AppColors.brandDark;
              glowColor = AppColors.brand;
              scale = 1.0;
          }
        } else {
          switch (_state) {
            case _ConvState.user_turn:
              orbColor = AppColors.brand;
              glowColor = AppColors.brandLight;
              scale = 1.0 + (pulse * 0.12);
            case _ConvState.ai_speaking:
              orbColor = const Color(0xFF3B82F6);
              glowColor = const Color(0xFF93C5FD);
            case _ConvState.processing:
            case _ConvState.ending:
              orbColor = AppColors.brandDark;
              glowColor = AppColors.brand;
              scale = 1.0;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale * 1.35,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbColor.withValues(
                        alpha: 0.10 * (1.0 - pulse)),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orbColor,
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildOrbContent(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrbContent() {
    switch (_state) {
      case _ConvState.processing:
      case _ConvState.ending:
        // Single static icon — the card center already has the spinner.
        return Center(
          child: Icon(
            _state == _ConvState.ending
                ? Icons.analytics_outlined
                : Icons.hourglass_top_rounded,
            color: AppColors.inkOnDark.withValues(alpha: 0.7),
            size: 28,
          ),
        );
      case _ConvState.user_turn:
        return const Center(
          child: Icon(Icons.mic, color: AppColors.inkOnDark, size: 34),
        );
      case _ConvState.ai_speaking:
        // In live voice the mic stays on even while AI speaks — show mic icon
        // dimmed so the user knows they can barge in at any time.
        if (_isLiveVoiceActive) {
          return Center(
            child: Icon(Icons.mic,
                color: AppColors.inkOnDark.withValues(alpha: 0.45), size: 34),
          );
        }
        return Center(
          child: Icon(
            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color:
                _isMuted ? AppColors.inkOnDark.withValues(alpha: 0.35) : AppColors.inkOnDark,
            size: 32,
          ),
        );
    }
  }

  // ─── Conversation card (hero element) ─────────────────────────────────────────

  Widget _buildConversationCard() {
    final Color borderColor;
    final Color accentColor;

    switch (_state) {
      case _ConvState.user_turn:
        borderColor = AppColors.brand.withValues(alpha: 0.35);
        accentColor = AppColors.brand;
      case _ConvState.ai_speaking:
        borderColor = const Color(0xFF3B82F6).withValues(alpha: 0.35);
        accentColor = const Color(0xFF3B82F6);
      case _ConvState.processing:
      case _ConvState.ending:
        borderColor = AppColors.outline;
        accentColor = AppColors.inkSoft;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: speaker dot + label + REC badge ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: accentColor),
                ),
                const SizedBox(width: 8),
                Text(
                  _getSpeakerLabel(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // REC badge only in classic HTTP mode
                if (_state == _ConvState.user_turn && !_isLiveVoiceActive)
                  _buildRecordingBadge(),
                // Live indicator in live voice mode
                if (_isLiveVoiceActive) _buildLivePill(),
              ],
            ),

            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 1,
              color: borderColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),

            // ── Main content — cross-fade on every state change ───────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey<String>(
                    '${_state.name}_${_isLiveVoiceActive}_$_isOpeningLoading',
                  ),
                  child: _buildCardContent(),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  String _getSpeakerLabel() {
    switch (_state) {
      case _ConvState.user_turn:
        return 'YOU';
      case _ConvState.ai_speaking:
        return widget.config.persona.toUpperCase();
      case _ConvState.processing:
        return 'PROCESSING';
      case _ConvState.ending:
        return 'EVALUATING';
    }
  }

  Widget _buildRecordingBadge() {
    // Per-turn elapsed seconds, updated every second via the main timer tick.
    final secs = _micStartTime != null
        ? DateTime.now().difference(_micStartTime!).inSeconds
        : 0;
    final mins = secs ~/ 60;
    final s = secs % 60;
    final timeStr =
        mins > 0 ? '$mins:${s.toString().padLeft(2, '0')}' : '${s}s';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(
                    alpha: 0.5 + 0.5 * _pulseController.value),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'REC  $timeStr',
              style: TextStyle(
                color: AppColors.brandLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small "LIVE" pill shown in the card header during live voice ─────────────
  Widget _buildLivePill() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.scoreExcellent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.scoreExcellent.withValues(
                  alpha: 0.3 + 0.2 * _pulseController.value)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.scoreExcellent.withValues(
                    alpha: 0.6 + 0.4 * _pulseController.value),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                color: AppColors.scoreExcellent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Animated bars shown when AI is speaking in live voice ────────────────────
  Widget _buildAiSpeakingBars() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final phase =
              (_pulseController.value + i * 0.18) % 1.0;
          final h = 6.0 + 20.0 * math.sin(phase * math.pi).abs();
          return Container(
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6)
                  .withValues(alpha: 0.5 + 0.4 * math.sin(phase * math.pi)),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  /// Unified card content layout — all states share the same structural template:
  ///
  ///  ┌──────────────────────────────────────┐
  ///  │  [transcript / placeholder / loader]  │  ← Expanded, top-left anchored
  ///  │                                       │
  ///  │                                       │
  ///  │  [waveform bars]                      │  ← fixed bottom, always present
  ///  │  [status label]                        │    when relevant
  ///  └──────────────────────────────────────┘
  ///
  /// This eliminates the flicker/jump when state transitions shift content
  /// between center and top.
  Widget _buildCardContent() {
    // ── Processing / Ending (shared, no voice active needed) ──────────────────
    if (_state == _ConvState.processing || _state == _ConvState.ending) {
      final label = _state == _ConvState.ending
          ? 'Analysing your session...'
          : (_isOpeningLoading
              ? 'Connecting to ${widget.config.persona}...'
              : 'Processing...');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Center(child: _buildDotsLoader()),
          const SizedBox(height: 16),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
        ],
      );
    }

    // ── Determine what text to show in the main area ───────────────────────────
    final bool isUserTurn = _state == _ConvState.user_turn;
    final bool isAiSpeaking = _state == _ConvState.ai_speaking;

    // For user turns: prefer live STT partial, fallback to last confirmed transcript.
    final String userDisplayText = _isLiveVoiceActive
        ? _lastUserTranscript
        : (_liveTranscript.isNotEmpty ? _liveTranscript : _cardText);

    // For AI turns: karaoke chunk (set by live-voice messages or _streamLocalKaraoke).
    final String aiDisplayText = _karaokeChunk;

    final bool hasContent = isUserTurn
        ? userDisplayText.isNotEmpty
        : aiDisplayText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main text area — always top-anchored ─────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              child: hasContent
                  ? Text(
                      isUserTurn ? userDisplayText : aiDisplayText,
                      key: ValueKey<String>(
                          isUserTurn ? userDisplayText : aiDisplayText),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        letterSpacing: -0.1,
                      ),
                    )
                  : _buildEmptyPlaceholder(isUserTurn),
            ),
          ),
        ),

        // ── Bottom: waveform / AI bars + status hint ─────────────────────────
        const SizedBox(height: 12),
        if (isAiSpeaking)
          _buildAiSpeakingBars()
        else if (isUserTurn)
          _buildWaveformRow(),
        const SizedBox(height: 8),
        Text(
          isAiSpeaking
              ? '${widget.config.persona} is speaking'
              : (_isLiveVoiceActive ? 'Listening — speak anytime' : 'Speak clearly'),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  /// Subtle placeholder when there's no text yet — no pulsating opacity.
  Widget _buildEmptyPlaceholder(bool isUserTurn) {
    return Text(
      key: const ValueKey('placeholder'),
      isUserTurn ? 'Say something...' : '...',
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 17,
        fontStyle: FontStyle.italic,
        height: 1.6,
      ),
    );
  }


  // ─── Waveform row ─────────────────────────────────────────────────────────────

  Widget _buildWaveformRow() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(9, (i) {
            final sineNudge =
                math.sin((_waveformController.value * math.pi) + i * 0.8) *
                    0.15;
            final amp = i < _barAmplitudes.length
                ? (_barAmplitudes[i] + sineNudge).clamp(0.05, 1.0)
                : 0.15;
            final height = 4.0 + (22.0 * amp);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 3.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: AppColors.brandLight
                    .withValues(alpha: 0.5 + 0.5 * amp),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  // ─── Bottom controls ──────────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIconButton(
            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
            color:
                _isMuted ? AppColors.inkSoft : AppColors.ink,
            onTap: _toggleMute,
            tooltip: _isMuted ? 'Unmute AI' : 'Mute AI',
          ),
          _buildCenterAction(),
          _buildIconButton(
            icon: Icons.call_end_rounded,
            color: _canEndCall ? AppColors.inkOnDark : AppColors.inkSoft,
            backgroundColor: _canEndCall
                ? const Color(0xFFEF4444)
                : AppColors.surface,
            borderColor: _canEndCall
                ? const Color(0xFFEF4444)
                : AppColors.outline,
            glow: _canEndCall
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : null,
            onTap: _canEndCall ? _endSession : null,
            tooltip: _canEndCall
                ? 'End & get feedback'
                : 'Speak for ${math.max(0, 10 - _effectiveSpokenSeconds)}s more to end',
          ),
        ],
      ),
    );
  }

  Widget _buildCenterAction() {
    // ── Live voice connected → waveform pill, no manual buttons ───────────────
    if (_isLiveVoiceActive) {
      return _buildLiveVoiceStatusPill();
    }

    // ── Server enabled LiveKit but not yet attempted (opening audio playing) ──
    // Also covers the brief window between _liveVoiceAttempted=true and the
    // LiveKit connect() call resolving — neither state should show buttons.
    if (_serverLiveVoiceEnabled && !_liveVoiceAttempted) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 140,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bgSunk,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.outline),
        ),
        child: Center(child: _buildDotsLoader(size: 7)),
      );
    }

    // ── LiveKit attempted but failed → fallback HTTP buttons ──────────────────
    // Also: server never offered LiveKit at all → always classic HTTP.
    switch (_state) {
      case _ConvState.processing:
      case _ConvState.ending:
        // Card center already shows the spinner — keep bottom area empty.
        return const SizedBox(width: 140, height: 56);

      case _ConvState.ai_speaking:
        return GestureDetector(
          onTap: _onInterrupt,
          child: Container(
            width: 140,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pan_tool_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Text(
                  'INTERRUPT',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
              ],
            ),
          ),
        );

      case _ConvState.user_turn:
        return GestureDetector(
          onTap: _onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 140,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send_rounded, color: AppColors.inkOnDark, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SEND',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.inkOnDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
          ),
        );
    }
  }

  /// Center area in live voice mode — animated waveform bars that react to
  /// who is speaking. No buttons, no text labels — just visual feedback.
  Widget _buildLiveVoiceStatusPill() {
    final bool isAi = _state == _ConvState.ai_speaking;
    final bool isLoading = _state == _ConvState.processing ||
        _state == _ConvState.ending;

    final Color barColor = isAi
        ? const Color(0xFF3B82F6)
        : AppColors.brand;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 140,
      height: 56,
      decoration: BoxDecoration(
        color: isLoading
            ? AppColors.bgSunk
            : barColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLoading
              ? AppColors.outline
              : barColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox.shrink()
            : _buildLiveWaveformBars(barColor),
      ),
    );
  }

  /// 5 animated waveform bars — height driven by pulse for user,
  /// separate sine phases for AI (gives a different feel for each speaker).
  Widget _buildLiveWaveformBars(Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        const barCount = 5;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final phase = (_pulseController.value + i / barCount) % 1.0;
            final t = math.sin(phase * math.pi * 2).abs();
            final minH = 4.0;
            final maxH = _state == _ConvState.user_turn ? 22.0 : 16.0;
            final h = minH + (maxH - minH) * t;
            return Container(
              width: 3.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5 + 0.5 * t),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    Color? glow,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? AppColors.bgSunk,
          border: Border.all(color: borderColor ?? AppColors.outline),
          boxShadow: glow != null
              ? [BoxShadow(color: glow, blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}
