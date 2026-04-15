import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/feedback_config.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_feedback_screen.dart';

// ─── State machine ─────────────────────────────────────────────────────────────
//
//  user_turn  ──[SEND]──▶  processing  ──[AI response]──▶  ai_speaking
//      ▲                                                         │
//      └──────────────────[AI finishes or INTERRUPT]─────────────┘
//
enum _ConvState { user_turn, processing, ai_speaking, ending }

// ─── Screen ────────────────────────────────────────────────────────────────────

class RoleplayConversationScreen extends StatefulWidget {
  final RoleplayConfig config;

  /// Pass an empty string or omit to activate demo mode (no backend calls).
  final String sessionId;
  final bool isOnboarding;

  const RoleplayConversationScreen({
    super.key,
    required this.config,
    this.sessionId = 'demo',
    this.isOnboarding = false,
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
  _ConvState _state = _ConvState.user_turn;
  final List<Map<String, String>> _conversationHistory = [];

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

  /// End-call enabled after ≥ 10 s of speaking + not mid-processing.
  bool get _canEndCall =>
      _totalSpokenSeconds >= 10 && _state == _ConvState.user_turn;

  // ─── Audio ────────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;
  final List<String> _tempFiles = [];

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
    _startTimer();
    _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
    _startMic();
  }

  @override
  void dispose() {
    debugPrint(
        '🎙 [Conversation] Screen disposed — session=${widget.sessionId}');
    _sessionTimer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _stt.cancel();
    _cleanupTempFiles();
    super.dispose();
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
    debugPrint('✅ [Conversation] Mic active — turn #${_conversationHistory.length ~/ 2 + 1}, '
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
    await _audioPlayer.stop();
    await _startMic();
  }

  // ─── API: process turn ────────────────────────────────────────────────────────

  Future<void> _sendTurn(String audioPath) async {
    final turnNumber = _conversationHistory.length ~/ 2 + 1;
    debugPrint('🔄 [Conversation] Processing turn #$turnNumber...');

    // ── Demo mode ──────────────────────────────────────────────────────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final fakeUserTranscript =
          'Great to be here — let me tell you a bit about myself.';
      final replyIndex =
          (_conversationHistory.length ~/ 2).clamp(0, _demoReplies.length - 1);
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
      await _onAudioFinished();
      return;
    }

    // ── Real mode ──────────────────────────────────────────────────────────────
    try {
      final bytes = await File(audioPath).readAsBytes();
      final filename = audioPath.split(Platform.pathSeparator).last;

      final result = await SessionService.instance.processTurn(
        sessionId: widget.sessionId,
        audioBytes: Uint8List.fromList(bytes),
        filename: filename,
        conversationHistory: List.from(_conversationHistory),
      );

      _conversationHistory.addAll([
        {'role': 'user', 'transcript': result.userTranscript},
        {'role': 'ai', 'transcript': result.aiReply},
      ]);

      debugPrint('✅ [Conversation] Turn #$turnNumber complete');
      debugPrint('   User: "${result.userTranscript}"');
      debugPrint(
          '   AI:   "${result.aiReply.length > 80 ? '${result.aiReply.substring(0, 80)}...' : result.aiReply}"');

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
        _cardText = result.aiReply;
        _cardAnimKey++;
      });

      await _playBase64Audio(result.aiAudioBase64);
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
      await _onAudioFinished();
      return;
    }
    if (_isMuted) {
      debugPrint('🔇 [Conversation] Muted — skipping AI audio playback');
      await _onAudioFinished();
      return;
    }
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
      debugPrint(
          '🔊 [Conversation] AI audio finished — returning mic to user');
      _onAudioFinished();
    }
  }

  Future<void> _onAudioFinished() async {
    if (!mounted) return;
    await _startMic();
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

    debugPrint('');
    debugPrint('🏁 [Conversation] Ending session ─────────────────────');
    debugPrint('   sessionId:    ${widget.sessionId}');
    debugPrint(
        '   turns:        ${_conversationHistory.length ~/ 2}');
    debugPrint('   total time:   ${_secondsElapsed}s');
    debugPrint('   spoken time:  ${_totalSpokenSeconds}s');

    _stopMic();
    await _recorder.stop();
    _sessionTimer?.cancel();

    setState(() {
      _state = _ConvState.ending;
      _cardText = '';
      _cardAnimKey++;
    });

    // ── Demo mode ──────────────────────────────────────────────────────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplayFeedbackScreen(
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
            isOnboarding: widget.isOnboarding,
            xpAwarded: 50,
            newLevel: 1,
            leveledUp: false,
            newBadges: const [],
            newStreak: 1,
          ),
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplayFeedbackScreen(
            config: feedbackConfig,
            report: result.report,
            isOnboarding: widget.isOnboarding,
            xpAwarded: result.xpAwarded,
            newLevel: result.newLevel,
            leveledUp: result.leveledUp,
            newBadges: result.newBadges,
            newStreak: result.newStreak,
          ),
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
          Navigator.pop(context);
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
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold)),
        content: const Text(
            'Leaving now will abandon this session. Progress will not be saved.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay',
                style: TextStyle(color: AppColors.textSecondary)),
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
          'turns completed: ${_conversationHistory.length ~/ 2}, '
          'time: ${_secondsElapsed}s');
      _sessionTimer?.cancel();
      await _recorder.stop();
      await _audioPlayer.stop();
      SessionService.instance.abandonSession(widget.sessionId).ignore();
      _cleanupTempFiles();
      if (mounted) Navigator.pop(context);
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
        backgroundColor: AppColors.background,
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
    final glowColor = _state == _ConvState.ai_speaking
        ? const Color(0xFF3B82F6)
        : AppColors.primary;
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.15,
      left: MediaQuery.of(context).size.width * 0.5 - 160,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.08),
              blurRadius: 140,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
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
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _onWillPop,
          ),
          Column(
            children: [
              Text(
                widget.config.persona,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
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
                        color: AppColors.primaryLight.withValues(
                            alpha: 0.5 + 0.5 * _pulseController.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE SESSION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryLight,
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
    Color pillBg = AppColors.surface;
    Color pillBorder = AppColors.border;
    Color textColor = AppColors.textPrimary;

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

  // ─── Orb (compact) ────────────────────────────────────────────────────────────

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        double scale = 1.0 + (pulse * 0.06);

        Color orbColor;
        Color glowColor;
        switch (_state) {
          case _ConvState.user_turn:
            orbColor = AppColors.primary;
            glowColor = AppColors.primaryLight;
            scale = 1.0 + (pulse * 0.12);
          case _ConvState.ai_speaking:
            orbColor = const Color(0xFF3B82F6);
            glowColor = const Color(0xFF93C5FD);
          case _ConvState.processing:
          case _ConvState.ending:
            orbColor = AppColors.primaryDark;
            glowColor = AppColors.primary;
            scale = 1.0;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale * 1.4,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbColor.withValues(
                        alpha: 0.12 * (1.0 - pulse)),
                    width: 2,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: scale * 1.2,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbColor.withValues(
                        alpha: 0.25 * (1.0 - pulse)),
                    width: 2,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orbColor,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.45),
                      blurRadius: 24 + 16 * pulse,
                      spreadRadius: 3 * pulse,
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
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
        );
      case _ConvState.user_turn:
        return const Center(
          child: Icon(Icons.mic, color: Colors.white, size: 34),
        );
      case _ConvState.ai_speaking:
        return Center(
          child: Icon(
            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color:
                _isMuted ? Colors.white.withValues(alpha: 0.35) : Colors.white,
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
        borderColor = AppColors.primary.withValues(alpha: 0.35);
        accentColor = AppColors.primary;
      case _ConvState.ai_speaking:
        borderColor = const Color(0xFF3B82F6).withValues(alpha: 0.35);
        accentColor = const Color(0xFF3B82F6);
      case _ConvState.processing:
      case _ConvState.ending:
        borderColor = AppColors.border;
        accentColor = AppColors.textMuted;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 32,
          ),
        ],
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
                  width: 8,
                  height: 8,
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
                if (_state == _ConvState.user_turn) _buildRecordingBadge(),
              ],
            ),

            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 1,
              color: borderColor,
            ),
            const SizedBox(height: 16),

            // ── Main text content ─────────────────────────────────────────────
            Expanded(child: _buildCardContent()),

            // ── Waveform (only when recording) ────────────────────────────────
            if (_state == _ConvState.user_turn) ...[
              const SizedBox(height: 12),
              _buildWaveformRow(),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Speak clearly, then tap SEND',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
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
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                    alpha: 0.5 + 0.5 * _pulseController.value),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'REC  $timeStr',
              style: TextStyle(
                color: AppColors.primaryLight,
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

  Widget _buildCardContent() {
    switch (_state) {
      case _ConvState.user_turn:
        // Show live transcript from STT if available; otherwise placeholder.
        final displayText = _liveTranscript.isNotEmpty
            ? _liveTranscript
            : (_cardText.isNotEmpty ? _cardText : '');
        final isPlaceholder = displayText.isEmpty;

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: isPlaceholder
                ? _buildPlaceholderText()
                : Text(
                    displayText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      height: 1.65,
                    ),
                  ),
          ),
        );

      case _ConvState.processing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transcribing your response...',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Usually takes 5–15 seconds',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );

      case _ConvState.ai_speaking:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          child: Align(
            key: ValueKey<int>(_cardAnimKey),
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                _cardText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  height: 1.65,
                ),
              ),
            ),
          ),
        );

      case _ConvState.ending:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Generating your feedback...',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'This may take up to 60 seconds',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
    }
  }

  // Animated placeholder shown when the user hasn't spoken yet this turn.
  Widget _buildPlaceholderText() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Speak now',
            style: TextStyle(
              color: AppColors.textMuted.withValues(
                  alpha: 0.5 + 0.3 * _pulseController.value),
              fontSize: 17,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '...',
            style: TextStyle(
              color: AppColors.textMuted.withValues(
                  alpha: 0.3 + 0.5 * _pulseController.value),
              fontSize: 17,
            ),
          ),
        ],
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
                color: AppColors.primaryLight
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
                _isMuted ? AppColors.textMuted : AppColors.textPrimary,
            onTap: _toggleMute,
            tooltip: _isMuted ? 'Unmute AI' : 'Mute AI',
          ),
          _buildCenterAction(),
          _buildIconButton(
            icon: Icons.call_end_rounded,
            color: _canEndCall ? Colors.white : AppColors.textMuted,
            backgroundColor: _canEndCall
                ? const Color(0xFFEF4444)
                : AppColors.surface,
            borderColor: _canEndCall
                ? const Color(0xFFEF4444)
                : AppColors.border,
            glow: _canEndCall
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : null,
            onTap: _canEndCall ? _endSession : null,
            tooltip: _canEndCall
                ? 'End & get feedback'
                : 'Speak for ${math.max(0, 10 - _totalSpokenSeconds)}s more to end',
          ),
        ],
      ),
    );
  }

  Widget _buildCenterAction() {
    switch (_state) {
      case _ConvState.processing:
      case _ConvState.ending:
        return Container(
          width: 140,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            ),
          ),
        );

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
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SEND',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
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
          color: backgroundColor ?? AppColors.surface,
          border: Border.all(color: borderColor ?? AppColors.border),
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
