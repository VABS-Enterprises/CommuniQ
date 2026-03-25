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
  // ─── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _waveformController;

  // ─── Session state ───────────────────────────────────────────────────────────
  _ConvState _state = _ConvState.user_turn;
  String _displayText = 'Speak when ready — tap SEND when done.';

  final List<Map<String, String>> _conversationHistory = [];

  // Caption-style transcript state
  String? _captionText;
  String _captionSpeaker = '';    // 'You' or AI persona name
  int _captionKey = 0;           // incremented each turn for AnimatedSwitcher

  Timer? _sessionTimer;
  int _secondsElapsed = 0;
  int _totalSpokenSeconds = 0;
  DateTime? _micStartTime;

  bool _isMuted = false;

  // ─── Amplitude (real waveform) ───────────────────────────────────────────────
  Timer? _amplitudeTimer;
  // One value per bar — normalized 0.0–1.0, used only during user_turn.
  List<double> _barAmplitudes = List.filled(7, 0.15);

  /// True when running without a real session (onboarding demo, no auth).
  bool get _isDemoMode => widget.sessionId == 'demo' || widget.sessionId.isEmpty;

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

  /// End-call enabled after ≥ 10 s of speaking + not in the middle of
  /// processing or AI speech.
  bool get _canEndCall =>
      _totalSpokenSeconds >= 10 && _state == _ConvState.user_turn;

  // ─── Audio ───────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;
  final List<String> _tempFiles = [];

  // ─── Init / Dispose ──────────────────────────────────────────────────────────

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

    _startTimer();
    _audioPlayer.playerStateStream.listen(_onPlayerStateChange);
    _startMic();
  }

  @override
  void dispose() {
    debugPrint('🎙 [Conversation] Screen disposed — session=${widget.sessionId}');
    _sessionTimer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  // ─── Timer ───────────────────────────────────────────────────────────────────

  /// Returns the time limit in seconds, or null for "No limit".
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
        debugPrint('⏱ [Conversation] Time limit reached — auto-ending session');
        _endSession(force: true);
      }
    });
  }

  String get _formattedTime {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Returns seconds remaining, or null if no limit set.
  int? get _secondsRemaining {
    final limit = _timeLimitSeconds;
    if (limit == null) return null;
    return math.max(0, limit - _secondsElapsed);
  }

  // ─── Mic management ──────────────────────────────────────────────────────────

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

    // Poll mic amplitude every 80 ms and feed real values into the waveform bars.
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!mounted) return;
      try {
        final amp = await _recorder.getAmplitude();
        // getAmplitude returns dBFS in range (-∞, 0]. Map -60..0 → 0.05..1.0.
        final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
        if (mounted) {
          setState(() {
            // Shift left and add current amplitude at the end for a scrolling effect.
            _barAmplitudes = [..._barAmplitudes.sublist(1), normalized];
          });
        }
      } catch (_) {}
    });

    if (!mounted) return;
    setState(() {
      _state = _ConvState.user_turn;
      _displayText = 'Listening... tap SEND when done.';
      _captionSpeaker = 'You';
      _captionText = 'Listening...';
      _captionKey++;
    });
    // Speed up pulse while mic is on
    _pulseController.duration = const Duration(milliseconds: 800);
    _pulseController.repeat(reverse: true);
  }

  void _stopMic() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    // Reset bars to a quiet baseline so they don't freeze at last values.
    _barAmplitudes = List.filled(7, 0.15);

    if (_micStartTime != null) {
      final spokenSecs = DateTime.now().difference(_micStartTime!).inSeconds;
      _totalSpokenSeconds += spokenSecs;
      debugPrint('🎙 [Conversation] Mic stopped — spoke ${spokenSecs}s this turn, '
          'total ${_totalSpokenSeconds}s spoken');
      _micStartTime = null;
    }
    _pulseController.duration = const Duration(seconds: 2);
    _pulseController.repeat(reverse: true);
  }

  // ─── SEND ────────────────────────────────────────────────────────────────────

  Future<void> _onSend() async {
    if (_state != _ConvState.user_turn) return;

    HapticFeedback.mediumImpact();
    debugPrint('📤 [Conversation] SEND pressed — stopping recording...');
    _stopMic();

    final path = await _recorder.stop();

    if (!mounted) return;
    setState(() {
      _state = _ConvState.processing;
      _displayText = 'Processing your response...';
      _captionSpeaker = 'You';
      _captionText = 'Processing...';
      _captionKey++;
    });

    if (path == null) {
      debugPrint('❌ [Conversation] Recording path is null — mic failed');
      await _startMic();
      if (mounted) setState(() => _displayText = 'Recording failed. Try again.');
      return;
    }

    final fileSize = await File(path).length();
    debugPrint('📤 [Conversation] Sending audio: ${path.split('/').last} (${fileSize}B)');
    await _sendTurn(path);
  }

  // ─── INTERRUPT ────────────────────────────────────────────────────────────────

  Future<void> _onInterrupt() async {
    if (_state != _ConvState.ai_speaking) return;
    debugPrint('✋ [Conversation] INTERRUPT — stopping AI audio');
    HapticFeedback.lightImpact();

    await _audioPlayer.stop();
    // _onPlayerStateChange will NOT fire on manual stop, so transition manually.
    await _startMic();
  }

  // ─── API: process turn ────────────────────────────────────────────────────────

  Future<void> _sendTurn(String audioPath) async {
    final turnNumber = _conversationHistory.length ~/ 2 + 1;
    debugPrint('🔄 [Conversation] Processing turn #$turnNumber...');

    // ── Demo mode: use scripted responses, skip all backend calls ──────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1200)); // simulate latency
      if (!mounted) return;

      final fakeUserTranscript = 'Great to be here — let me tell you a bit about myself.';
      final replyIndex = (_conversationHistory.length ~/ 2)
          .clamp(0, _demoReplies.length - 1);
      final aiReply = _demoReplies[replyIndex];

      _conversationHistory.addAll([
        {'role': 'user', 'transcript': fakeUserTranscript},
        {'role': 'ai', 'transcript': aiReply},
      ]);

      setState(() {
        _captionSpeaker = 'You';
        _captionText = fakeUserTranscript;
        _captionKey++;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _displayText = aiReply;
        _state = _ConvState.ai_speaking;
        _captionSpeaker = widget.config.persona;
        _captionText = aiReply;
        _captionKey++;
      });
      // No audio in demo — go straight to next user turn.
      await _onAudioFinished();
      return;
    }

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
      debugPrint('   AI:   "${result.aiReply.length > 80 ? '${result.aiReply.substring(0, 80)}...' : result.aiReply}"');
      debugPrint('   Audio: ${result.aiAudioBase64.isEmpty ? "none" : "${result.aiAudioBase64.length} chars (base64)"}');

      if (!mounted) return;

      // Briefly show what the STT engine understood before the AI reply.
      if (result.userTranscript.isNotEmpty) {
        setState(() {
          _captionSpeaker = 'You';
          _captionText = result.userTranscript;
          _captionKey++;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
      }

      setState(() {
        _displayText = result.aiReply;
        _state = _ConvState.ai_speaking;
        _captionSpeaker = widget.config.persona;
        _captionText = result.aiReply;
        _captionKey++;
      });

      await _playBase64Audio(result.aiAudioBase64);
    } catch (e) {
      debugPrint('❌ [Conversation] Turn #$turnNumber failed: $e');
      if (!mounted) return;
      setState(() => _displayText = _friendlyError(e.toString()));
      // Restart mic so user can retry
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
      debugPrint('🔊 [Conversation] Playing AI audio (${bytes.length}B)...');
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ [Conversation] Audio playback failed: $e');
      await _onAudioFinished();
    }
  }

  void _onPlayerStateChange(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      debugPrint('🔊 [Conversation] AI audio finished — returning mic to user');
      _onAudioFinished();
    }
  }

  Future<void> _onAudioFinished() async {
    if (!mounted) return;
    // AI finished speaking — auto-start mic for the user's next turn.
    await _startMic();
  }

  // ─── Mute ─────────────────────────────────────────────────────────────────────

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);
    debugPrint('🔇 [Conversation] Mute toggled → ${_isMuted ? "MUTED" : "unmuted"}');
    if (_isMuted && _state == _ConvState.ai_speaking) {
      debugPrint('🔇 [Conversation] Stopping AI audio (muted mid-playback)');
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
    debugPrint('   turns:        ${_conversationHistory.length ~/ 2}');
    debugPrint('   total time:   ${_secondsElapsed}s');
    debugPrint('   spoken time:  ${_totalSpokenSeconds}s');

    _stopMic();
    await _recorder.stop();
    _sessionTimer?.cancel();

    setState(() {
      _state = _ConvState.ending;
      _displayText = 'Generating your feedback...';
    });

    // ── Demo mode: show scripted feedback, skip backend ────────────────────────
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 2)); // simulate eval delay
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
                SkillCard(title: 'Clarity & Fluency', score: 82, tags: ['Clear', 'Natural']),
                SkillCard(title: 'Confidence', score: 74, tags: ['Developing', 'Growing']),
                SkillCard(title: 'Vocabulary & Grammar', score: 79, tags: ['Solid', 'Good']),
                SkillCard(title: 'Pronunciation', score: 76, tags: ['Good', 'Solid']),
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

    try {
      debugPrint('⏳ [Conversation] Requesting AI evaluation (may take up to 90s)...');
      final result = await SessionService.instance.endSession(widget.sessionId);
      final feedbackConfig =
          result.report.toFeedbackConfig(widget.config.scenarioTitle);

      debugPrint('✅ [Conversation] Evaluation received');
      debugPrint('   XP awarded: ${result.xpAwarded}');
      debugPrint('   New level:  ${result.newLevel}');
      debugPrint('   Leveled up: ${result.leveledUp}');
      if (result.newBadges.isNotEmpty) {
        debugPrint('   New badges: ${result.newBadges.join(", ")}');
      }
      debugPrint('   Navigating to feedback screen...');
      debugPrint('');

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

      // The server already abandoned the session (no completed turns) or it is
      // no longer active. Retrying will always return 400, so navigate back
      // cleanly rather than looping forever.
      if (errStr.contains('No turns recorded') ||
          errStr.contains('not in progress') ||
          errStr.contains('abandoned')) {
        debugPrint('⚠️  [Conversation] Session already closed server-side — navigating back');
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

      // Transient error (network blip, AI timeout) — let the user retry.
      setState(() => _displayText = 'Could not generate feedback. Try again.');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Session?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      debugPrint('🗑  [Conversation] User chose to abandon — '
          'turns completed: ${_conversationHistory.length ~/ 2}, '
          'time: ${_secondsElapsed}s');
      _sessionTimer?.cancel();
      await _recorder.stop();
      await _audioPlayer.stop();
      // Best-effort: fire-and-forget abandon call.
      SessionService.instance.abandonSession(widget.sessionId).ignore();
      _cleanupTempFiles();
      if (mounted) Navigator.pop(context);
    } else {
      debugPrint('✅ [Conversation] User chose to stay');
    }
  }

  // ─── Cleanup ─────────────────────────────────────────────────────────────────

  void _cleanupTempFiles() {
    for (final path in _tempFiles) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _tempFiles.clear();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('Network')) {
      return 'Server not reachable. Check your connection.';
    }
    if (raw.contains('503')) return 'AI service unavailable. Try again.';
    if (raw.contains('400')) return 'Could not process audio. Try again.';
    return 'Something went wrong. Try again.';
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
            // Ambient background glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: MediaQuery.of(context).size.width * 0.5 - 150,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _state == _ConvState.ai_speaking
                          ? AppColors.primaryLight.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 120,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildOrbVisual(),
                        const SizedBox(height: 32),
                        _buildVoiceBars(),
                      ],
                    ),
                  ),
                  if (_captionText != null)
                    _buildCaptionDisplay(),
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => _onWillPop(),
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

  // ─── Orb visual ──────────────────────────────────────────────────────────────

  Widget _buildOrbVisual() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        double scale = 1.0 + (pulse * 0.08);

        Color orbColor;
        Color glowColor;
        switch (_state) {
          case _ConvState.user_turn:
            orbColor = AppColors.primary;
            glowColor = AppColors.primaryLight;
            scale = 1.0 + (pulse * 0.14); // larger pulse = mic active
          case _ConvState.ai_speaking:
            orbColor = const Color(0xFF3B82F6); // cool blue for AI
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
            // Outer ring
            Transform.scale(
              scale: scale * 1.4,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbColor.withValues(alpha: 0.15 * (1.0 - pulse)),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Middle ring
            Transform.scale(
              scale: scale * 1.2,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: orbColor.withValues(alpha: 0.3 * (1.0 - pulse)),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Core orb
            Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orbColor,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.45),
                      blurRadius: 30 + 20 * pulse,
                      spreadRadius: 4 * pulse,
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
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        );
      case _ConvState.user_turn:
        return const Center(
          child: Icon(Icons.mic, color: Colors.white, size: 42),
        );
      case _ConvState.ai_speaking:
        return Center(
          child: Icon(
            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: _isMuted
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white,
            size: 40,
          ),
        );
    }
  }

  // ─── Waveform bars ────────────────────────────────────────────────────────────

  Widget _buildVoiceBars() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            double height = 4.0;
            if (_state == _ConvState.ai_speaking) {
              // AI bars: smooth sine wave animation.
              final offset =
                  math.sin((_waveformController.value * math.pi * 2) + i);
              height = 8.0 + (18.0 * offset.abs());
            } else if (_state == _ConvState.user_turn) {
              // User bars: driven by real mic amplitude.
              // Add a small sine offset per bar so adjacent bars vary slightly.
              final sineNudge = math.sin((_waveformController.value * math.pi) + i * 0.8) * 0.15;
              final amp = (_barAmplitudes[i] + sineNudge).clamp(0.05, 1.0);
              height = 6.0 + (24.0 * amp);
            }
            final barColor = _state == _ConvState.ai_speaking
                ? const Color(0xFF93C5FD)
                : AppColors.primaryLight;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  // ─── Display text ─────────────────────────────────────────────────────────────

  Widget _buildDisplayText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Padding(
        key: ValueKey<String>(_displayText),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Text(
          _displayText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
      ),
    );
  }

  // ─── Caption display ─────────────────────────────────────────────────────────

  Widget _buildCaptionDisplay() {
    final isUser = _captionSpeaker == 'You';
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey<int>(_captionKey),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUser
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _captionSpeaker.toUpperCase(),
                style: TextStyle(
                  color: isUser ? AppColors.primaryLight : AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _captionText ?? '',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom controls ──────────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 32,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // End-call hint
          AnimatedOpacity(
            opacity: (!_canEndCall && _state == _ConvState.user_turn) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Speak for ${math.max(0, 10 - _totalSpokenSeconds)}s more to end the call',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Main action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mute button (always visible)
              _buildIconButton(
                icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                color: _isMuted ? AppColors.textMuted : AppColors.textPrimary,
                onTap: _toggleMute,
              ),

              // Center: SEND or INTERRUPT or spinner
              _buildCenterAction(),

              // End-call button
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
              ),
            ],
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
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
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
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pan_tool_rounded,
                    color: Color(0xFFEF4444), size: 18),
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
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(32),
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
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? AppColors.surface,
          border: Border.all(color: borderColor ?? AppColors.border),
          boxShadow: glow != null
              ? [BoxShadow(color: glow, blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
