import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:communiq/core/routes/app_router.dart' show FeedbackArgs;
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/gaze_detector_service.dart';
import 'package:communiq/core/services/live_voice_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/core/services/visual_analysis_calculator.dart';
import 'package:communiq/models/feedback_config.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/models/visual_analysis_models.dart';
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

  // ─── Camera Visual Analysis ──────────────────────────────────────────────────
  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  GazeDetectorService? _gazeService;
  bool _isCameraEnabled = false;

  /// Where the user has dragged the camera preview to, in screen coordinates.
  /// Null until first moved, so the default corner follows the screen size
  /// rather than a value captured at first build.
  Offset? _pipOffset;
  bool _isCameraInitializing = false;
  VisionFrameResult? _latestVisionFrame;
  final List<VisionFrameResult> _visionFrames = [];

  Future<void> _toggleCameraTracking() async {
    if (_isCameraEnabled) {
      _disableCameraTracking();
    } else {
      await _enableCameraTracking();
    }
  }

  Future<void> _enableCameraTracking() async {
    setState(() => _isCameraInitializing = true);
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _isCameraInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required for eye-contact tracking')),
        );
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception('No camera'),
      );

      _frontCamera = front;
      _gazeService ??= GazeDetectorService();

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraEnabled = true;
        _isCameraInitializing = false;
      });

      await controller.startImageStream((image) async {
        if (!mounted || !_isCameraEnabled || _gazeService == null || _frontCamera == null) return;
        if (_gazeService!.isProcessing) return;

        final res = await _gazeService!.processFrame(
          cameraImage: image,
          cameraDescription: _frontCamera!,
        );

        if (res != null && mounted) {
          setState(() => _latestVisionFrame = res);
          _visionFrames.add(res);
        }
      });
    } catch (e) {
      debugPrint('[RoleplayScreen] Camera error: $e');
      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    }
  }

  void _disableCameraTracking() {
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraEnabled = false;
        _latestVisionFrame = null;
      });
    }
  }

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
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _gazeService?.dispose();
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
      _startTimerIfNotStarted();
      await _onAudioFinished();
      return;
    }
    if (_isMuted) {
      debugPrint('🔇 [Conversation] Muted — skipping AI audio playback');
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
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ [Conversation] Audio playback failed: $e');
      await _onAudioFinished();
    }
  }

  void _onPlayerStateChange(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (_state != _ConvState.ai_speaking) return;
      debugPrint(
          '🔊 [Conversation] AI audio finished — returning mic to user');
      _onAudioFinished();
    }
  }

  Future<void> _onAudioFinished() async {
    if (!mounted) return;
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

    // ── Mark level complete in SharedPreferences ───────────────────────────────
    // This fires before any async AI call so the learning view always receives
    // a completion signal when it reads prefs on return, even if the AI fails.
    await _markLevelComplete();

    setState(() {
      _state = _ConvState.ending;
      _cardText = '';
      _cardAnimKey++;
    });

    // ── Compute Visual Session Result if Camera Eye-Tracking was enabled ──────
    VisionSessionResult? visualResult;
    if (_isCameraEnabled && _visionFrames.isNotEmpty) {
      visualResult = VisualAnalysisCalculator.calculateSessionResult(
        frames: List.from(_visionFrames),
      );
    }

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
            visualResult: visualResult,
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

      VisionSessionResult? finalVisualResult = visualResult;
      if (finalVisualResult != null) {
        try {
          debugPrint('⏳ [Conversation] Evaluating & saving roleplay visual report to Firestore...');
          final aiInsights = await SessionService.instance.evaluateAndSaveVisualReport(finalVisualResult);
          if (aiInsights != null && aiInsights.isNotEmpty) {
            finalVisualResult = finalVisualResult.copyWith(insights: aiInsights);
          }
        } catch (vErr) {
          debugPrint('⚠️ [Conversation] Visual report evaluation/save non-fatal error: $vErr');
        }
      }

      debugPrint('✅ [Conversation] Evaluation received');
      if (!mounted) return;
      // Page-based route: go through the router, or this throws on arrival at
      // the one screen the whole session exists to reach.
      context.pushReplacement(
        AppRoutes.roleplayFeedback,
        extra: FeedbackArgs(
          config: feedbackConfig,
          report: result.report,
          visualResult: finalVisualResult,
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
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.outline, width: 2),
        ),
        title: Text('Leave this session?', style: AppTextStyles.titleLarge),
        content: Text(
          'Your progress in this conversation will not be saved.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Leave',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.errorDark)),
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

  // ─── Build ────────────────────────────────────────────────────────────────
  //
  // The session reads as a stage: two speakers facing each other across a lane
  // of travelling dots, with the transcript below as the hero surface. Whoever
  // holds the turn owns the screen's accent — the persona speaks in brand
  // purple, you speak in gold — so a glance at any element says whose turn it
  // is. Replaces the previous dark-navy panel, which was the last screen still
  // on the retired neon palette.

  /// Accent for the current turn. Every tinted element reads from this, so the
  /// screen visibly hands over on each state change.
  Color get _turnAccent {
    switch (_state) {
      case _ConvState.user_turn:
        return AppColors.sunDark;
      case _ConvState.ai_speaking:
        return AppColors.brand;
      case _ConvState.processing:
      case _ConvState.ending:
        return AppColors.inkSoft;
    }
  }

  String get _personaInitial => widget.config.persona.trim().isEmpty
      ? '?'
      : widget.config.persona.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: PlayfulBackground(
        seed: 11,
        intensity: 0.5,
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    _buildTurnStage(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page),
                        child: _buildConversationCard(),
                      ),
                    ),
                    _buildBottomControls(),
                  ],
                ),
              ),
              if (_isCameraEnabled &&
                  _cameraController != null &&
                  _cameraController!.value.isInitialized)
                _buildCameraPip(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.s12, AppSpacing.page, AppSpacing.s8),
      child: Row(
        children: [
          _buildSquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: _onWillPop,
            tooltip: 'Leave session',
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.config.persona,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.config.role.isNotEmpty
                      ? widget.config.role
                      : widget.config.scenarioTitle,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          _buildCameraButton(),
          const SizedBox(width: AppSpacing.s8),
          _buildTimerPill(),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    final on = _isCameraEnabled;
    return _buildSquareButton(
      tooltip: on ? 'Turn off eye-contact camera' : 'Track eye contact',
      onTap: _toggleCameraTracking,
      fill: on ? AppColors.brandSoft : AppColors.surface,
      borderColor: on ? AppColors.brand : AppColors.outline,
      iconColor: on ? AppColors.brand : AppColors.inkMuted,
      icon: on ? Icons.videocam_rounded : Icons.videocam_outlined,
      busy: _isCameraInitializing,
    );
  }

  /// The timer earns colour only as it runs out: neutral, then gold under 30s,
  /// then red under 10s.
  Widget _buildTimerPill() {
    final remaining = _secondsRemaining;

    Color fill = AppColors.surface;
    Color edge = AppColors.outline;
    Color ink = AppColors.ink;

    if (remaining != null && remaining <= 10) {
      fill = AppColors.errorSoft;
      edge = AppColors.error;
      ink = AppColors.errorDark;
    } else if (remaining != null && remaining <= 30) {
      fill = AppColors.sunSoft;
      edge = AppColors.sunDark;
      ink = AppColors.sunDark;
    }

    final text = remaining != null
        ? '${(remaining ~/ 60).toString().padLeft(2, '0')}:'
            '${(remaining % 60).toString().padLeft(2, '0')}'
        : _formattedTime;

    return AnimatedContainer(
      duration: AppMotion.settle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: edge, width: 2),
        boxShadow: AppShadow.hardWith(edge, y: 3),
      ),
      child: Text(
        text,
        style: AppTextStyles.numeralSmall.copyWith(color: ink, fontSize: 15),
      ),
    );
  }

  // ─── Turn stage ───────────────────────────────────────────────────────────
  //
  // Two speakers with a lane of dots between them. The dots travel toward
  // whoever is listening, so the direction of the conversation is legible
  // without reading a word of it.

  Widget _buildTurnStage() {
    final aiTurn = _state == _ConvState.ai_speaking;
    final yourTurn = _state == _ConvState.user_turn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s24, AppSpacing.s8, AppSpacing.s24, AppSpacing.s16),
      child: Row(
        children: [
          _buildSpeakerAvatar(
            label: widget.config.persona,
            active: aiTurn,
            color: AppColors.brand,
            child: aiTurn || !yourTurn
                ? Text(
                    _personaInitial,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: aiTurn ? AppColors.inkOnDark : AppColors.inkMuted,
                      fontSize: 26,
                    ),
                  )
                : Text(
                    _personaInitial,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.inkMuted,
                      fontSize: 26,
                    ),
                  ),
          ),
          Expanded(child: _buildFlowLane()),
          _buildSpeakerAvatar(
            label: 'You',
            active: yourTurn,
            color: AppColors.sun,
            child: Icon(
              // In live voice the mic never closes, so it stays lit even while
              // the persona talks — that is what makes barging in discoverable.
              _isLiveVoiceActive || yourTurn
                  ? Icons.mic_rounded
                  : Icons.mic_off_rounded,
              size: 28,
              color: yourTurn ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerAvatar({
    required String label,
    required bool active,
    required Color color,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        // A zero-blur ring that expands and fades: the chunky system's answer
        // to a glow, and it reads as "sound leaving this speaker".
        final pulse = _pulseController.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.settle,
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color : AppColors.surface,
                border: Border.all(
                  color: active ? AppColors.shadowFor(color) : AppColors.outline,
                  width: 3,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35 * (1 - pulse)),
                          blurRadius: 0,
                          spreadRadius: 3 + 9 * pulse,
                        ),
                      ]
                    : AppShadow.subtle(),
              ),
              child: Center(child: child),
            ),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              width: 84,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: active ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlowLane() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        const count = 7;
        final towardUser = _state == _ConvState.ai_speaking;
        final towardPersona = _state == _ConvState.user_turn;
        final idle = !towardUser && !towardPersona;
        final color = idle ? AppColors.inkSoft : _turnAccent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              // Reversing the index reverses the direction of travel.
              final step = towardPersona ? count - 1 - i : i;
              final phase = (_pulseController.value + step / count) % 1.0;
              final t = idle ? 0.0 : math.sin(phase * math.pi);
              final size = 5.0 + 4.0 * t;
              return Container(
                width: size,
                height: size,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22 + 0.78 * t),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ─── Transcript card ──────────────────────────────────────────────────────

  Widget _buildConversationCard() {
    final accent = _turnAccent;

    return AnimatedContainer(
      duration: AppMotion.settle,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: AppShadow.hardWith(AppColors.outline, y: 4),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent stripe — the card's own turn indicator.
            AnimatedContainer(
              duration: AppMotion.settle,
              height: 6,
              color: accent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getSpeakerLabel(),
                          style: AppTextStyles.eyebrow.copyWith(color: accent),
                        ),
                        const Spacer(),
                        if (_isLiveVoiceActive)
                          _buildLivePill()
                        else if (_state == _ConvState.user_turn)
                          _buildRecordingBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s14),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.settle,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
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
            ),
          ],
        ),
      ),
    );
  }

  String _getSpeakerLabel() {
    switch (_state) {
      case _ConvState.user_turn:
        return 'YOUR TURN';
      case _ConvState.ai_speaking:
        return widget.config.persona.toUpperCase();
      case _ConvState.processing:
        return 'THINKING';
      case _ConvState.ending:
        return 'EVALUATING';
    }
  }

  Widget _buildRecordingBadge() {
    final secs = _micStartTime != null
        ? DateTime.now().difference(_micStartTime!).inSeconds
        : 0;
    final label = secs >= 60
        ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
        : '${secs}s';

    return _buildStatusPill(
      color: AppColors.error,
      fill: AppColors.errorSoft,
      label: 'REC $label',
    );
  }

  Widget _buildLivePill() {
    return _buildStatusPill(
      color: AppColors.successDark,
      fill: AppColors.successSoft,
      label: 'LIVE',
    );
  }

  /// Pill with a breathing dot — shared by REC and LIVE so the two read as the
  /// same kind of signal rather than two unrelated badges.
  Widget _buildStatusPill({
    required Color color,
    required Color fill,
    required String label,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(
                    alpha: 0.45 + 0.55 * _pulseController.value),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    if (_state == _ConvState.processing || _state == _ConvState.ending) {
      final label = _state == _ConvState.ending
          ? 'Analysing your session…'
          : (_isOpeningLoading
              ? 'Connecting to ${widget.config.persona}…'
              : 'Thinking about your answer…');
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDotsLoader(color: AppColors.brand),
          const SizedBox(height: AppSpacing.s16),
          Text(label,
              style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        ],
      );
    }

    final isUserTurn = _state == _ConvState.user_turn;
    final isAiSpeaking = _state == _ConvState.ai_speaking;

    final userText = _isLiveVoiceActive
        ? _lastUserTranscript
        : (_liveTranscript.isNotEmpty ? _liveTranscript : _cardText);
    final text = isUserTurn ? userText : _karaokeChunk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: AnimatedSwitcher(
              duration: AppMotion.quick,
              switchInCurve: Curves.easeOut,
              child: text.isNotEmpty
                  ? Text(
                      text,
                      key: ValueKey<String>(text),
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontSize: 19,
                        height: 1.55,
                        color: AppColors.ink,
                      ),
                    )
                  : _buildEmptyPlaceholder(isUserTurn),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (isAiSpeaking)
          Center(child: _buildAiSpeakingBars())
        else if (isUserTurn)
          _buildWaveformRow(),
        const SizedBox(height: AppSpacing.s8),
        Center(
          child: Text(
            isAiSpeaking
                ? '${widget.config.persona} is speaking'
                : (_isLiveVoiceActive
                    ? 'Listening — jump in whenever'
                    : 'Speak clearly, then send'),
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaceholder(bool isUserTurn) {
    return Text(
      key: const ValueKey('placeholder'),
      isUserTurn ? 'Your answer will appear here as you speak…' : '…',
      style: AppTextStyles.bodyLarge.copyWith(
        fontSize: 17,
        height: 1.55,
        color: AppColors.inkSoft,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ─── Motion pieces ────────────────────────────────────────────────────────

  Widget _buildDotsLoader({Color color = AppColors.brand, double size = 9}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = (_pulseController.value + i / 3.0) % 1.0;
          final t = math.sin(phase * math.pi);
          return Container(
            width: size,
            height: size,
            margin: EdgeInsets.symmetric(horizontal: size * 0.3),
            transform: Matrix4.translationValues(0, -t * size * 0.8, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.35 + 0.65 * t),
            ),
          );
        }),
      ),
    );
  }

  /// Your live mic level. Real amplitude, so it stops moving when you do.
  Widget _buildWaveformRow() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(11, (i) {
            final nudge =
                math.sin((_waveformController.value * math.pi) + i * 0.8) * 0.15;
            final amp = i < _barAmplitudes.length
                ? (_barAmplitudes[i] + nudge).clamp(0.05, 1.0)
                : 0.15;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 5,
              height: 6.0 + 24.0 * amp,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: AppColors.sunDark.withValues(alpha: 0.4 + 0.6 * amp),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAiSpeakingBars() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final phase = (_pulseController.value + i * 0.18) % 1.0;
          final t = math.sin(phase * math.pi).abs();
          return Container(
            width: 5,
            height: 8.0 + 22.0 * t,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.45 + 0.55 * t),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  // ─── Bottom controls ──────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.s16,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.s20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRoundButton(
            icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
            onTap: _toggleMute,
            fill: _isMuted ? AppColors.bgSunk : AppColors.surface,
            iconColor: _isMuted ? AppColors.inkSoft : AppColors.ink,
          ),
          _buildCenterAction(),
          _buildRoundButton(
            icon: Icons.call_end_rounded,
            tooltip: _canEndCall
                ? 'End & get feedback'
                : 'Speak ${math.max(0, 10 - _effectiveSpokenSeconds)}s more to end',
            onTap: _canEndCall ? _endSession : null,
            fill: _canEndCall ? AppColors.error : AppColors.bgSunk,
            borderColor: _canEndCall ? AppColors.errorDark : AppColors.outline,
            iconColor: _canEndCall ? AppColors.inkOnDark : AppColors.inkSoft,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterAction() {
    if (_isLiveVoiceActive) return _buildLiveVoiceStatusPill();

    // LiveKit offered but not yet connected — no buttons belong here yet.
    if (_serverLiveVoiceEnabled && !_liveVoiceAttempted) {
      return _buildActionShell(
        fill: AppColors.surface,
        border: AppColors.outline,
        child: _buildDotsLoader(color: AppColors.inkSoft, size: 7),
      );
    }

    switch (_state) {
      case _ConvState.processing:
      case _ConvState.ending:
        return const SizedBox(width: 168, height: 64);

      case _ConvState.ai_speaking:
        return _buildActionShell(
          onTap: _onInterrupt,
          fill: AppColors.surface,
          border: AppColors.error,
          child: _actionLabel(
              Icons.pan_tool_rounded, 'INTERRUPT', AppColors.errorDark),
        );

      case _ConvState.user_turn:
        return _buildActionShell(
          onTap: _onSend,
          fill: AppColors.brand,
          border: AppColors.brandDark,
          child:
              _actionLabel(Icons.send_rounded, 'SEND', AppColors.inkOnDark),
        );
    }
  }

  Widget _actionLabel(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: AppTextStyles.labelLarge.copyWith(color: color)),
      ],
    );
  }

  Widget _buildLiveVoiceStatusPill() {
    final isAi = _state == _ConvState.ai_speaking;
    final isLoading =
        _state == _ConvState.processing || _state == _ConvState.ending;
    final color = isAi ? AppColors.brand : AppColors.sunDark;

    return _buildActionShell(
      fill: isLoading
          ? AppColors.surface
          : (isAi ? AppColors.brandSoft : AppColors.sunSoft),
      border: isLoading ? AppColors.outline : color,
      child: isLoading
          ? const SizedBox.shrink()
          : _buildLiveWaveformBars(color),
    );
  }

  Widget _buildLiveWaveformBars(Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        const barCount = 5;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(barCount, (i) {
            final phase = (_pulseController.value + i / barCount) % 1.0;
            final t = math.sin(phase * math.pi * 2).abs();
            final maxH = _state == _ConvState.user_turn ? 24.0 : 18.0;
            return Container(
              width: 5,
              height: 5 + (maxH - 5) * t,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45 + 0.55 * t),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  /// The chunky pill the centre action always lives in — one shell so SEND,
  /// INTERRUPT and the live waveform share a footprint and never make the row
  /// jump between states.
  Widget _buildActionShell({
    required Color fill,
    required Color border,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final shell = AnimatedContainer(
      duration: AppMotion.settle,
      width: 168,
      height: 64,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: border, width: 2.5),
        boxShadow: AppShadow.hardWith(border, y: onTap == null ? 3 : 5),
      ),
      child: Center(child: child),
    );
    return onTap == null
        ? shell
        : GestureDetector(onTap: onTap, child: shell);
  }

  // ─── Buttons ──────────────────────────────────────────────────────────────

  Widget _buildSquareButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color fill = AppColors.surface,
    Color borderColor = AppColors.outline,
    Color iconColor = AppColors.ink,
    bool busy = false,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.settle,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppRadius.chipRadius,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: AppShadow.hardWith(borderColor, y: 3),
        ),
        child: busy
            ? Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: iconColor),
              )
            : Icon(icon, color: iconColor, size: 20),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    Color fill = AppColors.surface,
    Color? borderColor,
    Color iconColor = AppColors.ink,
  }) {
    final edge = borderColor ?? AppColors.outline;
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.settle,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: edge, width: 2.5),
          boxShadow: AppShadow.hardWith(edge, y: onTap == null ? 2 : 4),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  // ─── Camera picture-in-picture ────────────────────────────────────────────

  static const double _pipWidth = 108;
  static const double _pipHeight = 144;

  /// Keeps the preview fully on screen, whatever the drag or the rotation.
  Offset _clampPip(Offset offset) {
    final media = MediaQuery.of(context);
    const margin = AppSpacing.s8;
    return Offset(
      offset.dx.clamp(margin, media.size.width - _pipWidth - margin),
      offset.dy.clamp(
        media.padding.top + margin,
        media.size.height - _pipHeight - media.padding.bottom - margin,
      ),
    );
  }

  Widget _buildCameraPip() {
    final holding = _latestVisionFrame?.eyeContact == EyeContactState.yes;
    final edge = holding ? AppColors.success : AppColors.sunDark;

    // The preview used to be pinned to the top-right, where it covered the
    // persona's avatar and the timer. It is draggable now — anywhere on
    // screen, clamped to stay reachable.
    final media = MediaQuery.of(context);
    final offset = _pipOffset ??
        Offset(
          media.size.width - _pipWidth - AppSpacing.page,
          media.padding.top + 84,
        );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        onPanUpdate: (details) => setState(
          () => _pipOffset = _clampPip(offset + details.delta),
        ),
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.chipRadius,
          border: Border.all(color: edge, width: 3),
          boxShadow: AppShadow.hardWith(AppColors.shadowFor(edge), y: 4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chips - 3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraController!),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: edge,
                  child: Text(
                    holding ? 'EYE CONTACT' : 'LOOK UP',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: holding ? AppColors.inkOnDark : AppColors.ink,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              // Drag affordance — without it the preview reads as fixed.
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkOnDark70,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
