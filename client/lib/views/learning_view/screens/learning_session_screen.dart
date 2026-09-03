import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/confetti_overlay.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/learning_service.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/models/demo_evaluation_result.dart';

/// What the user has done with one MCQ step so far.
enum _StepStatus {
  /// Not answered yet this session.
  open,

  /// Answered wrongly; they can try again.
  wrong,

  /// Missed twice — the server has now sent the correct option so the step
  /// can teach rather than keep testing.
  revealed,

  /// Answered correctly.
  solved,
}

/// Per-step session state. One of these per MCQ.
class _StepState {
  int? selected;
  _StepStatus status = _StepStatus.open;
  String? feedback;
  String? correctOption;
  int coinsAwarded = 0;

  /// Solved before this session started — replayed, so it pays nothing.
  bool preSolved = false;

  bool get isDone =>
      status == _StepStatus.solved || status == _StepStatus.revealed;
}

/// A level, played start to finish: lesson → questions → written response →
/// summary.
///
/// Rebuilt on the light design system. The previous version was written for
/// the old dark theme and never migrated — it drew option text in
/// `Colors.white` on `AppColors.surface`, which is now pure white, so the
/// answers were invisible. Nothing here hardcodes a colour; it all comes from
/// [AppColors].
class LearningSessionScreen extends StatefulWidget {
  final CommuniqLevel level;
  final bool isAlreadyCompleted;

  /// The user's current server-known coin total, used to seed the header
  /// before the first graded answer of this session lands.
  final int initialCoins;

  const LearningSessionScreen({
    super.key,
    required this.level,
    this.isAlreadyCompleted = false,
    this.initialCoins = 0,
  });

  @override
  State<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends State<LearningSessionScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  int _page = 0;

  /// Mirrors the server's authoritative running total.
  int _coins = 0;

  /// Coins banked during this attempt, for the summary card.
  int _sessionCoins = 0;

  late final List<_StepState> _steps;

  bool _grading = false;
  bool _celebrate = false;

  // ── Written response ──
  final TextEditingController _textController = TextEditingController();
  /// Built on first use, not in [initState].
  ///
  /// The `record` plugin makes a platform call from its constructor, so
  /// creating it eagerly fired a channel message for every learner — including
  /// the majority who type their answer and never touch the mic.
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordStartTime;
  bool _isTranscribing = false;
  String? _voiceError;
  late final AnimationController _micPulse;

  DemoEvaluationResult? _evalResult;
  bool _isEvaluating = false;
  String? _evalError;

  LearningProgressStore get _store => LearningProgressStore.instance;

  int get _mcqCount => widget.level.mcqs.length;

  /// 0 = lesson, 1..n = MCQs, n+1 = response, n+2 = summary.
  int get _lessonPage => 0;
  int get _responsePage => _mcqCount + 1;
  int get _summaryPage => _mcqCount + 2;
  int get _totalPages => _mcqCount + 3;

  bool _isMcqPage(int page) => page >= 1 && page <= _mcqCount;
  int _stepIndexFor(int page) => page - 1;

  @override
  void initState() {
    super.initState();
    _coins = widget.initialCoins;
    _steps = List.generate(_mcqCount, (_) => _StepState());

    // Resume: any step the server already has recorded as correct is shown as
    // solved rather than asked again. Replaying a finished level re-shows the
    // content but never re-awards coins, so this costs the user nothing.
    for (var i = 0; i < _mcqCount; i++) {
      final step = widget.level.mcqs[i].step;
      if (_store.isStepSolved(widget.level.id, step)) {
        _steps[i]
          ..status = _StepStatus.solved
          ..preSolved = true
          ..feedback = 'You solved this one already.';
      }
    }

    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    _micPulse.dispose();
    _recorderInstance?.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(int page) {
    if (page < 0 || page >= _totalPages) return;
    _pageController.animateToPage(
      page,
      duration: AppMotion.settle,
      curve: AppMotion.ease,
    );
  }

  /// The first MCQ still unanswered, or the response page if they're all done.
  int get _firstUnfinishedPage {
    for (var i = 0; i < _mcqCount; i++) {
      if (_steps[i].status != _StepStatus.solved) return i + 1;
    }
    return _responsePage;
  }

  void _advance() {
    if (_page == _lessonPage) {
      _goTo(_firstUnfinishedPage);
      return;
    }
    if (_isMcqPage(_page)) {
      final idx = _stepIndexFor(_page);
      final state = _steps[idx];

      if (state.status == _StepStatus.wrong) {
        // "Try again" — clear the selection and let them re-answer.
        setState(() {
          state.status = _StepStatus.open;
          state.selected = null;
          state.feedback = null;
        });
        return;
      }
      if (state.status == _StepStatus.revealed) {
        _acknowledgeReveal();
        return;
      }
      if (!state.isDone) {
        _gradeCurrent();
        return;
      }
      _goTo(_page + 1);
      return;
    }
    if (_page == _responsePage) {
      _submitResponse();
    }
  }

  // ── MCQ grading ────────────────────────────────────────────────────────────
  //
  // Grading is server-authoritative (POST /learning/answer): the client sends
  // the exact option text the user tapped and renders whatever the server
  // decides. It must never compute correctness or coin awards itself — that
  // closed a loophole where a decompiled client could read the answer key
  // straight out of the shipped level data.

  Future<void> _gradeCurrent() async {
    final idx = _stepIndexFor(_page);
    final state = _steps[idx];
    final selected = state.selected;
    if (selected == null || _grading) return;

    final mcq = widget.level.mcqs[idx];

    setState(() => _grading = true);
    try {
      final result = await LearningService.submitAnswer(
        levelId: widget.level.id,
        // The server's own step number, not the page index. They happen to
        // line up today; sending the index would break the moment a level
        // ships with a non-contiguous step sequence.
        step: mcq.step,
        selectedOption: mcq.options[selected],
      );
      if (!mounted) return;

      setState(() {
        _grading = false;
        state.feedback = result.feedback;
        state.correctOption = result.correctOption;

        if (result.correct) {
          state.status = _StepStatus.solved;
          state.coinsAwarded = result.coinsAwarded;
          _coins = result.totalCoins;
          _sessionCoins += result.coinsAwarded;
        } else {
          state.status =
              result.revealed ? _StepStatus.revealed : _StepStatus.wrong;
        }
      });

      // Push the graded answer into the shared snapshot so the journey map
      // and anything else showing progress update in the same frame, rather
      // than waiting for this screen to pop.
      _store.applyAnswer(
        levelId: widget.level.id,
        step: mcq.step,
        result: result,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _grading = false);
      _snack('Could not check your answer: ${_clean(e)}');
    }
  }

  /// Records a revealed step against the server, then moves on.
  ///
  /// The server will not complete a level until every step is marked
  /// answered correctly, so a revealed step has to be submitted rather than
  /// merely skipped — otherwise anyone who used the reveal would reach the
  /// end and be refused completion. Submitting now costs the user the
  /// attempts they have already spent, so it pays the minimum coin award.
  Future<void> _acknowledgeReveal() async {
    final idx = _stepIndexFor(_page);
    final state = _steps[idx];
    final answer = state.correctOption;
    if (answer == null || _grading) {
      // Nothing to record — don't strand the user on this page.
      _goTo(_page + 1);
      return;
    }

    final mcq = widget.level.mcqs[idx];
    final optionIndex = mcq.options.indexOf(answer);

    setState(() {
      _grading = true;
      if (optionIndex >= 0) state.selected = optionIndex;
    });

    try {
      final result = await LearningService.submitAnswer(
        levelId: widget.level.id,
        step: mcq.step,
        selectedOption: answer,
      );
      if (!mounted) return;
      setState(() {
        _grading = false;
        state.status = _StepStatus.solved;
        state.coinsAwarded = result.coinsAwarded;
        _coins = result.totalCoins;
        _sessionCoins += result.coinsAwarded;
      });
      _store.applyAnswer(
        levelId: widget.level.id,
        step: mcq.step,
        result: result,
      );
      _goTo(_page + 1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _grading = false);
      _snack('Could not save that step: ${_clean(e)}');
    }
  }

  // ── Written response ───────────────────────────────────────────────────────

  Future<void> _submitResponse() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isEvaluating) return;

    setState(() {
      _isEvaluating = true;
      _evalError = null;
    });

    try {
      final result = await LearningService.evaluateLearningResponse(
        question: widget.level.responsePrompt.isNotEmpty
            ? widget.level.responsePrompt
            : widget.level.scenario,
        userResponse: text,
        topic: widget.level.journeyTitle.isNotEmpty
            ? widget.level.journeyTitle
            : widget.level.title,
        difficulty: widget.level.difficulty,
      );
      if (!mounted) return;
      setState(() {
        _evalResult = result;
        _isEvaluating = false;
      });

      // The server verifies every MCQ step independently, then awards the
      // response coins and the completion bonus. The response coins used to
      // be added client-side and never persisted, so the server total could
      // never reach what the UI had already shown.
      try {
        final completion = await LearningService.completeLevel(
          widget.level.id,
          responseScore: result.overallScore,
        );
        if (!mounted) return;
        setState(() {
          _coins = completion.totalCoins;
          _sessionCoins += completion.coinsAwarded;
        });
        _store.applyCompletion(
          levelId: widget.level.id,
          result: completion,
          responseScore: result.overallScore,
        );
      } catch (e) {
        // Non-fatal: the evaluation still stands and the MCQ coins are
        // already banked. Only the completion bonus is missed, and a later
        // refresh will reconcile if the server did record it.
        debugPrint('[LearningSession] completeLevel failed: $e');
      }

      if (!mounted) return;
      setState(() => _celebrate = true);
      _goTo(_summaryPage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isEvaluating = false;
        _evalError = _clean(e);
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;

    if (_isRecording) {
      final elapsed = _recordStartTime == null
          ? 99999
          : DateTime.now().difference(_recordStartTime!).inMilliseconds;
      if (elapsed < 1500) {
        setState(() => _voiceError = 'Keep speaking, then tap stop.');
        return;
      }

      final path = await _recorder.stop();
      _micPulse
        ..stop()
        ..reset();
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
        final base = _textController.text.trimRight();
        final merged = base.isEmpty ? transcript : '$base $transcript';
        setState(() {
          _isTranscribing = false;
          _voiceError = null;
          _textController.value = TextEditingValue(
            text: merged,
            selection: TextSelection.collapsed(offset: merged.length),
          );
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isTranscribing = false;
          _voiceError = _clean(e);
        });
      }
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() => _voiceError = 'Microphone permission required.');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/learning_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    _recordStartTime = DateTime.now();
    setState(() {
      _isRecording = true;
      _voiceError = null;
    });
    _micPulse.repeat(reverse: true);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Fraction of the level finished — every MCQ plus the written response.
  double get _completion {
    final done = _steps.where((s) => s.status == _StepStatus.solved).length +
        (_evalResult != null ? 1 : 0);
    return (done / widget.level.totalSteps).clamp(0.0, 1.0);
  }

  Future<void> _confirmExit() async {
    final unfinished = _steps.any((s) => s.status != _StepStatus.solved);
    if (!unfinished || _page == _summaryPage) {
      _close();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Text('Leave this level?', style: AppTextStyles.titleLarge),
        content: Text(
          'Your solved questions are saved — you can pick up right where you '
          'left off.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep going', style: AppTextStyles.labelLarge),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Leave',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (leave == true) _close();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop({
      'coins': _sessionCoins,
      'score': _evalResult?.overallScore,
      'completed': _evalResult != null,
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: ConfettiOverlay(
        play: _celebrate,
        child: PlayfulBackground(
          seed: widget.level.id,
          child: Scaffold(
            backgroundColor: AppColors.transparent,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _totalPages,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) {
                        if (i == _lessonPage) return _lessonView();
                        if (i == _responsePage) return _responseView();
                        if (i == _summaryPage) return _summaryView();
                        return _mcqView(_stepIndexFor(i));
                      },
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.close_rounded,
                onTap: _confirmExit,
                semanticLabel: 'Close level',
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: ChunkyProgressBar(
                  value: _completion,
                  color: AppColors.success,
                  height: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              StatPill(
                icon: Icons.monetization_on_rounded,
                value: '$_coins',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Text(
                _headerLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const Spacer(),
              if (widget.isAlreadyCompleted)
                Text(
                  'Replay — no coins',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _headerLabel {
    if (_page == _lessonPage) return 'The idea';
    if (_page == _responsePage) return 'Your turn';
    if (_page == _summaryPage) return 'Level complete';
    return 'Question ${_stepIndexFor(_page) + 1} of $_mcqCount';
  }

  // ── Lesson ─────────────────────────────────────────────────────────────────

  Widget _lessonView() {
    final level = widget.level;
    final teaching = level.teaching;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s4,
        AppSpacing.page,
        AppSpacing.s24,
      ),
      children: [
        FadeInUp(
          child: Row(
            children: [
              Text(level.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.title, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppSpacing.s6),
                    Row(
                      children: [
                        if (level.skill.isNotEmpty)
                          _Tag(label: level.skill, color: AppColors.brand),
                        if (level.skill.isNotEmpty)
                          const SizedBox(width: AppSpacing.s6),
                        _Tag(
                          label: level.difficulty,
                          color: _difficultyColor(level.difficulty),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (level.goal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          FadeInUp(
            delay: AppMotion.staggerFor(1),
            child: Text(
              level.goal,
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s20),

        // The situation.
        FadeInUp(
          delay: AppMotion.staggerFor(2),
          child: ChunkyCard(
            fill: AppColors.surfaceAlt,
            accent: AppColors.sun,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE SITUATION',
                  style: AppTextStyles.eyebrow.copyWith(color: AppColors.sunDark),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  level.scenario,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),

        if (!teaching.isEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          FadeInUp(
            delay: AppMotion.staggerFor(3),
            child: ChunkyCard(
              accent: AppColors.brand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Mascot(
                        mood: MascotMood.thinking,
                        size: 52,
                        animate: false,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          teaching.idea,
                          style: AppTextStyles.titleMedium.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  if (teaching.points.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s16),
                    for (var i = 0; i < teaching.points.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              i == teaching.points.length - 1 ? 0 : AppSpacing.s12,
                        ),
                        child: _TeachingPoint(
                          index: i + 1,
                          text: teaching.points[i],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        FadeInUp(
          delay: AppMotion.staggerFor(4),
          child: Text(
            '$_mcqCount questions, then one you write yourself.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'advanced':
        return AppColors.error;
      case 'intermediate':
        return AppColors.sunDark;
      default:
        return AppColors.success;
    }
  }

  // ── MCQ ────────────────────────────────────────────────────────────────────

  Widget _mcqView(int index) {
    final mcq = widget.level.mcqs[index];
    final state = _steps[index];
    final locked = state.isDone || state.status == _StepStatus.wrong;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s4,
        AppSpacing.page,
        AppSpacing.s24,
      ),
      children: [
        Text(
          mcq.question,
          style: AppTextStyles.titleLarge.copyWith(height: 1.35),
        ),
        const SizedBox(height: AppSpacing.s20),
        for (var i = 0; i < mcq.options.length; i++)
          _AnswerOption(
            label: mcq.options[i],
            letter: String.fromCharCode(65 + i),
            state: _optionVisual(state, i, mcq.options[i]),
            onTap: locked || _grading
                ? null
                : () => setState(() => state.selected = i),
          ),
        if (state.feedback != null) ...[
          const SizedBox(height: AppSpacing.s8),
          _FeedbackPanel(
            status: state.status,
            message: state.feedback!,
            coins: state.preSolved ? 0 : state.coinsAwarded,
            correctOption: state.status == _StepStatus.revealed
                ? state.correctOption
                : null,
          ),
        ],
      ],
    );
  }

  _OptionVisual _optionVisual(_StepState state, int i, String label) {
    final isSelected = state.selected == i;
    final isCorrectOption =
        state.correctOption != null && state.correctOption == label;

    switch (state.status) {
      case _StepStatus.solved:
        // Pre-solved steps have no recorded selection, so mark the option the
        // server named rather than one the user tapped this session.
        if (isSelected || (state.preSolved && isCorrectOption)) {
          return _OptionVisual.correct;
        }
        return _OptionVisual.dimmed;
      case _StepStatus.revealed:
        if (isCorrectOption) return _OptionVisual.correct;
        if (isSelected) return _OptionVisual.incorrect;
        return _OptionVisual.dimmed;
      case _StepStatus.wrong:
        if (isSelected) return _OptionVisual.incorrect;
        return _OptionVisual.dimmed;
      case _StepStatus.open:
        return isSelected ? _OptionVisual.selected : _OptionVisual.idle;
    }
  }

  // ── Written response ───────────────────────────────────────────────────────

  Widget _responseView() {
    final level = widget.level;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s4,
        AppSpacing.page,
        AppSpacing.s24,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Mascot(mood: MascotMood.listening, size: 56),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                level.responsePrompt.isNotEmpty
                    ? level.responsePrompt
                    : level.scenario,
                style: AppTextStyles.titleMedium.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        ChunkyCard(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                maxLines: 6,
                minLines: 4,
                enabled: !_isEvaluating,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyLarge,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Write what you would actually say…',
                  hintStyle: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.inkSoft),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(AppSpacing.s8),
                ),
              ),
              const Divider(color: AppColors.outline),
              Row(
                children: [
                  _MicButton(
                    isRecording: _isRecording,
                    isTranscribing: _isTranscribing,
                    pulse: _micPulse,
                    onTap: _isEvaluating ? null : _toggleRecording,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      _isTranscribing
                          ? 'Transcribing…'
                          : _isRecording
                              ? 'Listening — tap to stop'
                              : 'Or say it out loud',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  Text(
                    '${_textController.text.trim().length}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_voiceError != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _InlineNotice(message: _voiceError!, color: AppColors.error),
        ],
        if (_evalError != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _InlineNotice(message: _evalError!, color: AppColors.error),
        ],
        if (_isEvaluating) ...[
          const SizedBox(height: AppSpacing.s24),
          const LoadingStateView(label: 'Reading your answer…'),
        ],
      ],
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Widget _summaryView() {
    final result = _evalResult;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s4,
        AppSpacing.page,
        AppSpacing.s24,
      ),
      children: [
        Center(
          child: Column(
            children: [
              const Mascot(mood: MascotMood.celebrating, size: 116),
              const SizedBox(height: AppSpacing.s12),
              Text(widget.level.title, style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.s4),
              Text(
                widget.isAlreadyCompleted
                    ? 'Replayed — nicely done.'
                    : widget.level.responseSuccessFeedback,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Coins earned',
                value: '+$_sessionCoins',
                color: AppColors.sun,
                icon: Icons.monetization_on_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _SummaryTile(
                label: 'Response score',
                value: result != null ? '${result.overallScore}' : '—',
                color: AppColors.brand,
                icon: Icons.auto_awesome_rounded,
              ),
            ),
          ],
        ),
        if (result != null) ...[
          if (result.feedback.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            ChunkyCard(
              accent: AppColors.brand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ON YOUR ANSWER',
                    style: AppTextStyles.eyebrow
                        .copyWith(color: AppColors.brandDark),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    result.feedback,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          if (result.scores.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            ChunkyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in result.scores.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                      child: _ScoreRow(
                        label: entry.key,
                        score: entry.value,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (result.strengths.isNotEmpty)
            _BulletCard(
              title: 'What worked',
              items: result.strengths,
              color: AppColors.success,
              icon: Icons.check_circle_rounded,
            ),
          if (result.improvements.isNotEmpty)
            _BulletCard(
              title: 'What to try next',
              items: result.improvements,
              color: AppColors.sunDark,
              icon: Icons.trending_up_rounded,
            ),
        ],
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _footer() {
    if (_page == _summaryPage) {
      return _footerShell(
        ChunkyButton(
          label: 'Back to the journey',
          icon: Icons.map_rounded,
          expand: true,
          onPressed: _close,
        ),
      );
    }

    if (_page == _lessonPage) {
      return _footerShell(
        ChunkyButton(
          label: _steps.every((s) => s.status == _StepStatus.solved)
              ? 'Continue'
              : "Let's go",
          icon: Icons.arrow_forward_rounded,
          expand: true,
          onPressed: _advance,
        ),
      );
    }

    if (_page == _responsePage) {
      final ready = _textController.text.trim().length >= 5;
      return _footerShell(
        ChunkyButton(
          label: 'Submit answer',
          icon: Icons.send_rounded,
          expand: true,
          loading: _isEvaluating,
          onPressed: ready && !_isEvaluating ? _advance : null,
        ),
      );
    }

    // MCQ page.
    final state = _steps[_stepIndexFor(_page)];
    final (label, variant) = switch (state.status) {
      _StepStatus.solved => ('Continue', ChunkyButtonVariant.success),
      _StepStatus.revealed => ('Got it', ChunkyButtonVariant.primary),
      _StepStatus.wrong => ('Try again', ChunkyButtonVariant.danger),
      _StepStatus.open => ('Check', ChunkyButtonVariant.primary),
    };

    return _footerShell(
      Row(
        children: [
          if (_page > 1)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s12),
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => _goTo(_page - 1),
                semanticLabel: 'Previous question',
              ),
            ),
          Expanded(
            child: ChunkyButton(
              label: label,
              variant: variant,
              expand: true,
              loading: _grading,
              onPressed: (state.status == _StepStatus.open &&
                          state.selected == null) ||
                      _grading
                  ? null
                  : _advance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerShell(Widget child) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s12,
        AppSpacing.page,
        AppSpacing.s12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 2)),
      ),
      child: child,
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

enum _OptionVisual { idle, selected, correct, incorrect, dimmed }

/// One answer choice.
///
/// Every colour here resolves from [AppColors]; the previous implementation
/// drew this text in `Colors.white`, which became invisible when the app moved
/// to a light theme.
class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.letter,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String letter;
  final _OptionVisual state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, border, ink, badgeFill, badgeInk) = switch (state) {
      _OptionVisual.correct => (
          AppColors.successSoft,
          AppColors.success,
          AppColors.ink,
          AppColors.success,
          AppColors.inkOnDark,
        ),
      _OptionVisual.incorrect => (
          AppColors.errorSoft,
          AppColors.error,
          AppColors.ink,
          AppColors.error,
          AppColors.inkOnDark,
        ),
      _OptionVisual.selected => (
          AppColors.brandSoft,
          AppColors.brand,
          AppColors.ink,
          AppColors.brand,
          AppColors.inkOnDark,
        ),
      _OptionVisual.dimmed => (
          AppColors.surface,
          AppColors.outline,
          AppColors.inkSoft,
          AppColors.bgSunk,
          AppColors.inkSoft,
        ),
      _OptionVisual.idle => (
          AppColors.surface,
          AppColors.outline,
          AppColors.ink,
          AppColors.bgSunk,
          AppColors.inkMuted,
        ),
    };

    final showTick = state == _OptionVisual.correct;
    final showCross = state == _OptionVisual.incorrect;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Semantics(
        button: onTap != null,
        selected: state == _OptionVisual.selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.ease,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s14,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: border, width: 2),
              boxShadow: state == _OptionVisual.dimmed
                  ? null
                  : AppShadow.hardWith(border, y: 3),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeFill,
                    shape: BoxShape.circle,
                  ),
                  child: showTick
                      ? Icon(Icons.check_rounded,
                          size: 18, color: AppColors.inkOnDark)
                      : showCross
                          ? Icon(Icons.close_rounded,
                              size: 18, color: AppColors.inkOnDark)
                          : Text(
                              letter,
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: badgeInk),
                            ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: ink, height: 1.35),
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

/// The verdict panel under a graded question.
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.status,
    required this.message,
    required this.coins,
    this.correctOption,
  });

  final _StepStatus status;
  final String message;
  final int coins;

  /// Set only when the user has run out of attempts, so the panel can show
  /// what the right answer was.
  final String? correctOption;

  @override
  Widget build(BuildContext context) {
    final solved = status == _StepStatus.solved;
    final revealed = status == _StepStatus.revealed;

    final color = solved
        ? AppColors.success
        : revealed
            ? AppColors.brand
            : AppColors.error;
    final title = solved
        ? 'Exactly right'
        : revealed
            ? "Here's the answer"
            : 'Not quite';
    final mood = solved
        ? MascotMood.happy
        : revealed
            ? MascotMood.thinking
            : MascotMood.encouraging;

    return ChunkyCard(
      fill: AppColors.surface,
      accent: color,
      borderColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Mascot(mood: mood, size: 40),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(color: color),
                ),
              ),
              if (coins > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sunSoft,
                    borderRadius: AppRadius.pillRadius,
                    border: Border.all(color: AppColors.sun, width: 2),
                  ),
                  child: Text(
                    '+$coins',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.sunDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Text(message, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
          if (correctOption != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: AppRadius.chipRadius,
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded,
                      size: 18, color: AppColors.successDark),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      correctOption!,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeachingPoint extends StatelessWidget {
  const _TeachingPoint({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.brandDark),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      accent: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.s8),
          Text(value, style: AppTextStyles.numeral.copyWith(color: color)),
          const SizedBox(height: AppSpacing.s2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.success
        : score >= 45
            ? AppColors.sunDark
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label[0].toUpperCase() + label.substring(1),
                style: AppTextStyles.labelMedium,
              ),
            ),
            Text('$score', style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        ChunkyProgressBar(value: score / 100, color: color, height: 10),
      ],
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: ChunkyCard(
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: color),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isRecording,
    required this.isTranscribing,
    required this.pulse,
    required this.onTap,
  });

  final bool isRecording;
  final bool isTranscribing;
  final AnimationController pulse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? AppColors.error : AppColors.brand;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) => Transform.scale(
          scale: isRecording ? 1 + pulse.value * 0.14 : 1,
          child: child,
        ),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: AppShadow.hardWith(
              AppColors.shadowFor(color),
              y: 3,
            ),
          ),
          child: isTranscribing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.inkOnDark),
                  ),
                )
              : Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: AppColors.inkOnDark,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}
