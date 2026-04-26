import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/demo_evaluation_result.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

enum _Phase { teaser, input, loading, result }

class RoleplayIntroScreen extends StatefulWidget {
  const RoleplayIntroScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<RoleplayIntroScreen> createState() => _RoleplayIntroScreenState();
}

class _RoleplayIntroScreenState extends State<RoleplayIntroScreen>
    with TickerProviderStateMixin {
  // ── Phase state ────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.teaser;
  DemoEvaluationResult? _result;
  String? _errorMessage;

  // ── Text input ─────────────────────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  static const int _minChars = 30;
  static const int _maxChars = 500;

  // ── Audio recorder + upload ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;
  DateTime? _recordStartTime;
  String? _voiceError;

  // ── Mic recording pulse ────────────────────────────────────────────────────
  late AnimationController _micRecordCtrl;
  late Animation<double> _micRecordPulse;

  // ── Mic pulse / wave (teaser only) ─────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _entranceCtrl;
  late Animation<double> _micScale;
  late Animation<double> _micGlow;
  late Animation<double> _fadeContent;
  late Animation<Offset> _slideContent;

  // ── Phase-transition controller ────────────────────────────────────────────
  late AnimationController _phaseCtrl;
  late Animation<double> _phaseFade;
  late Animation<Offset> _phaseSlide;

  // ── Result entrance ────────────────────────────────────────────────────────
  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  // ── Score ring ─────────────────────────────────────────────────────────────
  late AnimationController _ringCtrl;
  late Animation<double> _ringProgress;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _micScale = Tween<double>(begin: 0.93, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _micGlow = Tween<double>(begin: 0.3, end: 0.6).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeContent = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _slideContent = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));

    _phaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _phaseFade = CurvedAnimation(parent: _phaseCtrl, curve: Curves.easeOut);
    _phaseSlide = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _phaseCtrl, curve: Curves.easeOut));

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut));

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringProgress = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _micRecordCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _micRecordPulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _micRecordCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _entranceCtrl.dispose();
    _phaseCtrl.dispose();
    _resultCtrl.dispose();
    _ringCtrl.dispose();
    _micRecordCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Voice input ────────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;

    if (_isRecording) {
      // ── Guard: require at least 1.5 s of audio ───────────────────────────
      final elapsed = _recordStartTime == null
          ? 99999
          : DateTime.now().difference(_recordStartTime!).inMilliseconds;
      if (elapsed < 1500) {
        setState(() => _voiceError = 'Keep speaking, then tap stop.');
        return;
      }

      final path = await _recorder.stop();
      _micRecordCtrl.stop();
      _micRecordCtrl.reset();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
        _voiceError = null;
      });

      if (path == null) {
        setState(() => _isTranscribing = false);
        return;
      }

      try {
        final transcript = await OnboardingService.transcribeDemoAudio(path);
        if (!mounted) return;
        final base = _textCtrl.text.trimRight();
        final newText = base.isEmpty ? transcript : '$base $transcript';
        setState(() {
          _isTranscribing = false;
          _voiceError = null;
          _textCtrl.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        });
      } catch (e) {
        if (!mounted) return;
        final raw = e.toString();
        String msg;
        if (raw.contains('No speech') || raw.contains('no speech') || raw.contains('silence')) {
          msg = 'No speech detected — speak close to the mic and try again.';
        } else if (raw.contains('too small') || raw.contains('too short') || raw.contains('1 KB')) {
          msg = 'Recording too short. Speak for a few seconds then tap stop.';
        } else if (raw.contains('network') || raw.contains('connection') || raw.contains('SocketException')) {
          msg = 'Network error. Check your connection and retry.';
        } else {
          msg = raw.replaceFirst('Exception: ', '');
        }
        setState(() {
          _isTranscribing = false;
          _voiceError = msg;
        });
      }
      return;
    }

    // ── Start recording ──────────────────────────────────────────────────────
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _voiceError = 'Microphone permission required.');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/demo_intro_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: _recordingPath!,
    );

    _recordStartTime = DateTime.now();
    setState(() {
      _isRecording = true;
      _voiceError = null;
    });
    _micRecordCtrl.repeat(reverse: true);
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  Future<void> _goToSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    await OnboardingService.saveLocally(widget.data);
    if (!mounted) return;
    Navigator.push(
      context,
      slideRoute(SignupScreen(onboardingData: widget.data)),
    );
  }

  // ── Phase transitions ──────────────────────────────────────────────────────

  void _enterInputPhase() {
    setState(() {
      _phase = _Phase.input;
      _errorMessage = null;
    });
    _phaseCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _submitIntro() async {
    final text = _textCtrl.text.trim();
    if (text.length < _minChars) {
      setState(() => _errorMessage = 'Please write at least $_minChars characters.');
      return;
    }

    setState(() {
      _phase = _Phase.loading;
      _errorMessage = null;
    });
    _focusNode.unfocus();

    try {
      final result = await OnboardingService.evaluateDemoIntro(text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.result;
      });
      _ringCtrl.forward(from: 0);
      _resultCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.input;
        _errorMessage = 'Could not reach the AI coach. Check your connection and try again.';
      });
      _phaseCtrl.forward(from: 0);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: OnboardingBackground(
        child: SafeArea(
          child: switch (_phase) {
            _Phase.teaser => _buildTeaserBody(),
            _Phase.input || _Phase.loading => _buildInputBody(),
            _Phase.result => _buildResultBody(),
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1 — TEASER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTeaserBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          buildOnboardingHeader(context, 6),
          const Spacer(flex: 1),

          AnimatedBuilder(
            animation: Listenable.merge([_pulseCtrl, _waveCtrl]),
            builder: (_, __) => _buildMicVisual(),
          ),

          const SizedBox(height: 32),

          FadeTransition(
            opacity: _fadeContent,
            child: SlideTransition(
              position: _slideContent,
              child: Column(
                children: [
                  const Text(
                    'Your first roleplay\nawaits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Practice with a real scenario the moment\nyou create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildScenarioCard(),
                  const SizedBox(height: 16),
                  _buildFeatureRow(),
                ],
              ),
            ),
          ),

          const Spacer(flex: 2),

          OnboardingButton(
            label: "Try the Demo — It's Free",
            showGradient: true,
            onPressed: _enterInputPhase,
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: _goToSignup,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text(
              'Skip for now →',
              style: TextStyle(fontSize: 14),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2 — INPUT + LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputBody() {
    final isLoading = _phase == _Phase.loading || _isTranscribing;

    return FadeTransition(
      opacity: _phaseFade,
      child: SlideTransition(
        position: _phaseSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              buildOnboardingHeader(context, 6),
              const SizedBox(height: 36),

              // Icon + heading
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 28),
              ),

              const SizedBox(height: 20),

              const Text(
                'Say hello to\nyour AI coach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Type or speak a short intro — your name, what you do, and why you want to speak better. Your AI coach will give you instant feedback.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),

              const SizedBox(height: 28),

              // Text field
              _buildTextField(isLoading),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              _buildMicInputRow(isLoading),

              const Spacer(),

              // CTA button
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, __) {
                  final canSubmit = !isLoading &&
                      !_isRecording &&
                      _textCtrl.text.trim().length >= _minChars;
                  return _buildEvaluateButton(isLoading, canSubmit);
                },
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => setState(() => _phase = _Phase.teaser),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text('← Back', style: TextStyle(fontSize: 14)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(bool disabled) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textCtrl,
      builder: (_, value, __) {
        final len = value.text.trim().length;
        final atMin = len >= _minChars;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: disabled
                      ? AppColors.glassBorder
                      : atMin
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.glassBorder,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                enabled: !disabled,
                maxLines: 6,
                minLines: 4,
                maxLength: _maxChars,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    const SizedBox.shrink(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText:
                      'e.g. "Hi, I\'m Arjun. I\'m a software developer from Bangalore. I want to improve my English communication for client meetings and presentations..."',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.55,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '$len / $_maxChars  ·  min $_minChars chars',
              style: TextStyle(
                color: atMin ? AppColors.success : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEvaluateButton(bool isLoading, bool canSubmit) {
    return GestureDetector(
      onTap: canSubmit ? _submitIntro : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: canSubmit
              ? const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canSubmit ? null : AppColors.surfaceVariant,
          boxShadow: canSubmit
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: canSubmit ? Colors.white : AppColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Evaluate My Intro',
                      style: TextStyle(
                        color: canSubmit ? Colors.white : AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3 — RESULT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultBody() {
    final r = _result!;

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              buildOnboardingHeader(context, 6),
              const SizedBox(height: 24),

              // ── Score hero ────────────────────────────────────────────────
              _buildScoreHero(r.overallScore),

              const SizedBox(height: 20),

              // ── Sub-scores ────────────────────────────────────────────────
              _buildSection(
                icon: Icons.bar_chart_rounded,
                iconColor: AppColors.primary,
                title: 'Skill Breakdown',
                child: _buildScoreBars(r.scores),
              ),

              const SizedBox(height: 16),

              // ── Strengths ─────────────────────────────────────────────────
              _buildSection(
                icon: Icons.verified_rounded,
                iconColor: AppColors.success,
                title: 'What you did well',
                child: _buildPointList(r.strengths, AppColors.success),
              ),

              const SizedBox(height: 16),

              // ── Improvements ──────────────────────────────────────────────
              _buildSection(
                icon: Icons.lightbulb_rounded,
                iconColor: AppColors.amber,
                title: 'AI Tips for you',
                child: _buildPointList(r.improvements, AppColors.amber),
              ),

              const SizedBox(height: 16),

              // ── Feedback paragraph ────────────────────────────────────────
              _buildFeedbackCard(r.feedback),

              const SizedBox(height: 28),

              // ── CTA ───────────────────────────────────────────────────────
              _buildResultCta(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHero(int overall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.violet.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Ring + score
          AnimatedBuilder(
            animation: _ringProgress,
            builder: (_, __) => SizedBox(
              width: 90,
              height: 90,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  progress: _ringProgress.value * overall / 100,
                  score: overall,
                  color: _scoreColor(overall),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$overall',
                        style: TextStyle(
                          color: _scoreColor(overall),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scoreBadgeLabel(overall),
                  style: TextStyle(
                    color: _scoreColor(overall),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your AI coach analysed your introduction and scored it live.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1),
                  ),
                  child: const Text(
                    'AI-powered · instant',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildScoreBars(Map<String, int> scores) {
    const labels = {
      'accuracy': 'Accuracy',
      'depth': 'Depth',
      'clarity': 'Clarity',
      'examples': 'Examples',
    };

    return Column(
      children: labels.entries.map((e) {
        final score = scores[e.key] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildBar(e.value, score),
        );
      }).toList(),
    );
  }

  Widget _buildBar(String label, int score) {
    final color = _scoreColor(score);
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _ringProgress,
            builder: (_, __) {
              final progress = (_ringProgress.value * score / 100).clamp(0.0, 1.0);
              return Stack(
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text(
            '$score',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointList(List<String> points, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((pt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  accentColor == AppColors.success
                      ? Icons.check_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: accentColor,
                  size: 11,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pt,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedbackCard(String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.violetLight, size: 15),
              SizedBox(width: 8),
              Text(
                'AI Coach says',
                style: TextStyle(
                  color: AppColors.violetLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            feedback,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCta() {
    return Column(
      children: [
        // Separator hint
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.glassBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'WANT YOUR FULL PROGRESS TRACKED?',
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.glassBorder)),
          ],
        ),

        const SizedBox(height: 20),

        // Primary CTA
        GestureDetector(
          onTap: _goToSignup,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Create Account — It\'s Free',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Secondary benefit nudge
        const Text(
          'Track every session · Unlock all scenarios · Level up faster',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED TEASER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMicVisual() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...[0.0, 0.33, 0.66].map((offset) {
            final t = ((_waveCtrl.value + offset) % 1.0);
            final scale = 0.5 + t * 0.9;
            final alpha = (1.0 - t) * 0.25;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: alpha),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
          Transform.scale(
            scale: _micScale.value,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _micGlow.value),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SCENARIO',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_open_rounded,
                  color: AppColors.success, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Unlocked',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Introduce yourself',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us about yourself in a relaxed, friendly conversation. '
            'A great place to start your journey.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildChip(Icons.face_retouching_natural_rounded, 'Friendly AI'),
              const SizedBox(width: 8),
              _buildChip(Icons.timer_outlined, '2 min'),
              const SizedBox(width: 8),
              _buildChip(Icons.bar_chart_rounded, 'Beginner'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFeaturePill(Icons.insights_rounded, 'AI scoring'),
        const SizedBox(width: 8),
        _buildFeaturePill(Icons.replay_rounded, 'Instant replay'),
        const SizedBox(width: 8),
        _buildFeaturePill(Icons.lightbulb_rounded, 'Live tips'),
      ],
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.violetLight, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMicInputRow(bool disabled) {
    if (_isTranscribing) {
      return const Center(
        child: Column(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Transcribing…',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _micRecordCtrl,
      builder: (_, __) {
        final scale = _isRecording ? _micRecordPulse.value : 1.0;
        final bgColor = _isRecording ? AppColors.error : AppColors.primary;
        final glowColor = _isRecording
            ? AppColors.error.withValues(alpha: 0.35)
            : AppColors.primary.withValues(alpha: 0.25);
        final isBusy = disabled || _isTranscribing;

        return Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: isBusy ? null : _toggleRecording,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBusy
                          ? AppColors.surfaceVariant
                          : bgColor,
                      boxShadow: isBusy
                          ? null
                          : [
                              BoxShadow(
                                color: glowColor,
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: isBusy ? AppColors.textMuted : Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording ? 'Recording… tap to stop' : 'Or tap to speak',
                style: TextStyle(
                  color: _isRecording ? AppColors.error : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_voiceError != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _voiceError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.success;
    if (score >= 50) return AppColors.amber;
    return AppColors.error;
  }

  String _scoreBadgeLabel(int score) {
    if (score >= 85) return 'Outstanding!';
    if (score >= 70) return 'Well done!';
    if (score >= 55) return 'Good start!';
    return 'Keep practising!';
  }
}

// ── Score ring painter ─────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final int score;
  final Color color;

  _ScoreRingPainter({
    required this.progress,
    required this.score,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    const strokeWidth = 7.0;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
