import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/learning_service.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/models/demo_evaluation_result.dart';

class LearningSessionScreen extends StatefulWidget {
  final CommuniqLevel level;
  final bool isAlreadyCompleted;

  /// The user's current server-known coin total (learning_view's
  /// `_totalCoins`), used to seed the header display before the first
  /// server response arrives this session.
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
  int _currentPageIndex = 0;

  // Header display — mirrors the server's authoritative running coin total
  // (updated from LearningAnswerResult.totalCoins on every graded MCQ).
  int _coins = 0;

  // Coins earned specifically during this level attempt (cosmetic, used only
  // for the per-level breakdown shown on the learning map's milestone cards —
  // NOT used to gate anything, since the real gate is the server's `coins`
  // total reconciled in learning_view.dart).
  int _levelCoinsEarned = 0;

  // State for each page (N MCQs + 1 Response)
  late List<bool> _isSubmitted;

  // MCQ States
  late List<int?> _selectedOptionIndices;
  late List<List<String>> _mcqOptionsList;

  /// Per-step feedback returned by the server after grading. The client has no
  /// answer key, so this is the only source of the message shown to the user.
  late List<String?> _stepFeedback;
  late List<int> _mcqAttemptsList;
  late List<bool> _isMcqWrongList;
  // Coins awarded per MCQ step, as returned by the server (drives the "+N
  // Coins" badge — never computed locally from attempt count).
  late List<int> _mcqCoinsAwarded;
  bool _isSubmittingMcq = false;

  final TextEditingController _textController = TextEditingController();

  // Response: audio recorder
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordStartTime;
  bool _isTranscribing = false;
  String? _voiceError;

  // Mic pulse animation
  late AnimationController _micRecordCtrl;
  late Animation<double> _micRecordPulse;

  // AI evaluation result for the response page
  DemoEvaluationResult? _evalResult;
  bool _isEvaluating = false;
  String? _evalError;

  @override
  void initState() {
    super.initState();
    _coins = widget.initialCoins;
    final mcqCount = widget.level.mcqs.length;
    final totalPages = mcqCount + 1;

    _isSubmitted = List.filled(totalPages, false);
    _selectedOptionIndices = List.filled(mcqCount, null);
    _mcqAttemptsList = List.filled(mcqCount, 0);
    _isMcqWrongList = List.filled(mcqCount, false);
    _mcqCoinsAwarded = List.filled(mcqCount, 0);
    _mcqOptionsList = [];
    _stepFeedback = List.filled(mcqCount, null);

    for (final mcq in widget.level.mcqs) {
      _mcqOptionsList.add(mcq.options);
    }

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
    _pageController.dispose();
    _textController.dispose();
    _micRecordCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Voice recording ────────────────────────────────────────────────────────

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
        final base = _textController.text.trimRight();
        final newText = base.isEmpty ? transcript : '$base $transcript';
        setState(() {
          _isTranscribing = false;
          _voiceError = null;
          _textController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        });
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isTranscribing = false;
          _voiceError = msg;
        });
      }
      return;
    }

    // Start recording
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _voiceError = 'Microphone permission required.');
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/learning_response_${DateTime.now().millisecondsSinceEpoch}.wav';

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
    _micRecordCtrl.repeat(reverse: true);
  }

  // ── MCQ submission ─────────────────────────────────────────────────────────
  //
  // Grading is server-authoritative (POST /learning/answer): the client only
  // sends the exact option text the user tapped and renders whatever the
  // server decides. It must never compute correctness or coin awards itself
  // — that closed a loophole where a decompiled client could read the
  // answer key straight out of static_levels.dart.

  Future<void> _submitMcqPage() async {
    final idx = _currentPageIndex;
    if (_isMcqWrongList[idx]) {
      setState(() {
        _isMcqWrongList[idx] = false;
        _selectedOptionIndices[idx] = null;
      });
      return;
    }

    final selectedIdx = _selectedOptionIndices[idx];
    if (selectedIdx == null || _isSubmittingMcq) return;

    setState(() => _isSubmittingMcq = true);
    try {
      final result = await LearningService.submitAnswer(
        levelId: widget.level.id,
        // Server's learningLevels.json steps are 1-based (step: 1..5),
        // matching the original content data — idx is the client's 0-based
        // page index, so it must be converted here.
        step: idx + 1,
        selectedOption: _mcqOptionsList[idx][selectedIdx],
      );
      if (!mounted) return;
      setState(() {
        _isSubmittingMcq = false;
        _stepFeedback[idx] = result.feedback;
        if (result.correct) {
          _isSubmitted[idx] = true;
          _mcqCoinsAwarded[idx] = result.coinsAwarded;
          if (!widget.isAlreadyCompleted) {
            _coins = result.totalCoins;
            _levelCoinsEarned += result.coinsAwarded;
          }
        } else {
          _mcqAttemptsList[idx]++;
          _isMcqWrongList[idx] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingMcq = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check your answer: $msg')),
      );
    }
  }

  // ── Response submission with AI evaluation ─────────────────────────────────

  Future<void> _submitResponsePage() async {
    final responseText = _textController.text.trim();
    if (responseText.isEmpty) return;

    setState(() {
      _isEvaluating = true;
      _evalError = null;
    });

    try {
      final result = await LearningService.evaluateLearningResponse(
        question: widget.level.responsePrompt.isNotEmpty
            ? widget.level.responsePrompt
            : widget.level.scenario,
        userResponse: responseText,
        topic: widget.level.journeyTitle.isNotEmpty
            ? widget.level.journeyTitle
            : widget.level.title,
        difficulty: _difficultyForJourney(widget.level.journeyId),
      );
      
      if (!mounted) return;
      setState(() {
        _evalResult = result;
        _isEvaluating = false;
        _isSubmitted[_currentPageIndex] = true;

        // Note: the free-text response isn't covered by the new
        // /learning/answer contract (that endpoint only grades MCQ steps),
        // so its coin bonus is still computed from the AI evaluation score
        // returned by /levels/evaluate rather than a dedicated grading
        // endpoint. Only award coins if this is the first time completing
        // the level.
        if (!widget.isAlreadyCompleted) {
          final score = result.overallScore;
          int responseCoins = 1;
          if (score > 75) {
            responseCoins = 10;
          } else if (score > 50) {
            responseCoins = 7;
          } else if (score > 30) {
            responseCoins = 4;
          }
          _coins += responseCoins;
          _levelCoinsEarned += responseCoins;
        }
      });

      // Ask the server to verify + mark the level complete. It independently
      // checks that every MCQ step was answered correctly before allowing
      // this to succeed, so a rejection here is expected/non-fatal if our
      // local flow ever gets out of sync — never crash on it.
      if (!widget.isAlreadyCompleted) {
        try {
          await LearningService.completeLevel(widget.level.id);
        } catch (e) {
          debugPrint(
              '[LearningSessionScreen] completeLevel failed (non-fatal): $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isEvaluating = false;
        _evalError = msg;
      });
    }
  }

  String _difficultyForJourney(int journeyId) {
    if (journeyId <= 2) return 'beginner';
    if (journeyId <= 4) return 'intermediate';
    return 'advanced';
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _nextPage() {
    final totalPages = widget.level.mcqs.length + 1;
    if (_currentPageIndex < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context, {
        'coins': _levelCoinsEarned,
        'score': _evalResult?.overallScore,
      });
    }
  }

  void _prevPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canSubmit() {
    final mcqCount = widget.level.mcqs.length;
    if (_currentPageIndex < mcqCount) {
      if (_isSubmittingMcq) return false;
      if (_isMcqWrongList[_currentPageIndex]) return true;
      if (_isSubmitted[_currentPageIndex]) return false;
      return _selectedOptionIndices[_currentPageIndex] != null;
    } else {
      if (_isSubmitted[_currentPageIndex]) return false;
      if (_isEvaluating || _isRecording || _isTranscribing) return false;
      return _textController.text.trim().isNotEmpty;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.level.mcqs.length + 1;
    final isResponsePage = _currentPageIndex == widget.level.mcqs.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.level.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: List.generate(totalPages, (index) {
                final isActive = index <= _currentPageIndex;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPageIndex = index),
              children: [
                ...List.generate(widget.level.mcqs.length, (i) => _buildMcqPage(i)),
                _buildResponsePage(),
              ],
            ),
          ),

          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: ((_currentPageIndex > 0 && _isSubmitted[_currentPageIndex]) ||
                            (_currentPageIndex > 0 && _isSubmitted[_currentPageIndex - 1]))
                        ? AppColors.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: ((_currentPageIndex > 0 && _isSubmitted[_currentPageIndex]) ||
                            (_currentPageIndex > 0 && _isSubmitted[_currentPageIndex - 1]))
                        ? _prevPage
                        : null,
                    color: Colors.white,
                    disabledColor: Colors.white24,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AnimatedBuilder(
                      animation: _textController,
                      builder: (context, _) {
                        final isMcq = _currentPageIndex < widget.level.mcqs.length;
                        final isWrong = isMcq && _isMcqWrongList[_currentPageIndex];
                        final canTap = _canSubmit();

                        return ElevatedButton(
                          onPressed: canTap
                              ? (isMcq ? _submitMcqPage : _submitResponsePage)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: (_isEvaluating && isResponsePage) ||
                                  (_isSubmittingMcq && isMcq)
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isWrong ? 'Try Again' : 'Submit',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _isSubmitted[_currentPageIndex]
                        ? AppColors.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _currentPageIndex == totalPages - 1
                        ? const Icon(Icons.check_rounded)
                        : const Icon(Icons.arrow_forward_ios_rounded),
                    onPressed: _isSubmitted[_currentPageIndex] ? _nextPage : null,
                    color: Colors.white,
                    disabledColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MCQ Page ──────────────────────────────────────────────────────────────

  Widget _buildMcqPage(int index) {
    final mcq = widget.level.mcqs[index];
    final isSubmitted = _isSubmitted[index];
    final isWrong = _isMcqWrongList[index];

    return _buildPageContainer(
      title: 'Step ${index + 1}: Knowledge Check',
      description: mcq.question.isNotEmpty ? mcq.question : widget.level.scenario,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...List.generate(_mcqOptionsList[index].length, (optionIdx) {
            final isSelected = _selectedOptionIndices[index] == optionIdx;
            // With no local key, "correct" is simply the option the server
            // accepted — known only once this step has been submitted.
            final isCorrectOption =
                _isSubmitted[index] && optionIdx == _selectedOptionIndices[index];
            
            Color itemColor = AppColors.surface;
            Color borderColor = AppColors.border;
            if (isSubmitted && isCorrectOption) {
              itemColor = Colors.green.withOpacity(0.15);
              borderColor = Colors.green;
            } else if (isWrong && isSelected) {
              itemColor = Colors.red.withOpacity(0.15);
              borderColor = Colors.red;
            } else if (isSelected) {
              itemColor = AppColors.primary.withOpacity(0.15);
              borderColor = AppColors.primary;
            }

            return GestureDetector(
              onTap: (isSubmitted || isWrong) ? null : () => setState(() => _selectedOptionIndices[index] = optionIdx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: itemColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor.withOpacity(0.5),
                    width: (isSelected || (isSubmitted && isCorrectOption)) ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? borderColor : Colors.white54,
                          width: 2,
                        ),
                        color: isSelected ? borderColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _mcqOptionsList[index][optionIdx],
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    if (isSubmitted && isCorrectOption)
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    if (isWrong && isSelected)
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                  ],
                ),
              ),
            );
          }),
          if (isSubmitted || isWrong) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (isSubmitted ? Colors.green : Colors.red).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSubmitted ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: isSubmitted ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSubmitted ? 'Well Done!' : 'Not Quite',
                        style: TextStyle(
                          color: isSubmitted ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isSubmitted) ...[
                        const Spacer(),
                        Text(
                          '+${_mcqCoinsAwarded[index]} Coins',
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stepFeedback[index] ??
                        (isSubmitted ? 'Correct!' : 'Not quite — try again.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Response Page ─────────────────────────────────────────────────────────

  Widget _buildResponsePage() {
    final responseIdx = widget.level.mcqs.length;
    if (_isSubmitted[responseIdx]) {
      return _evalResult != null
          ? _buildResponseEvaluationScreen(_evalResult!)
          : _buildEvaluationScreen(
              widget.level.responseSuccessFeedback.isNotEmpty
                  ? widget.level.responseSuccessFeedback
                  : 'Great job! Your response was excellent.',
              true,
            );
    }

    return _buildPageContainer(
      title: 'Final Step: Craft Your Response',
      description: widget.level.responsePrompt.isNotEmpty
          ? widget.level.responsePrompt
          : widget.level.scenario,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 5,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
              decoration: const InputDecoration(
                hintText: 'Type your response here...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Mic row (same as demo screen)
          _buildMicInputRow(),

          // Evaluation error
          if (_evalError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _evalError!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
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

  // ─── Mic input row (identical to demo screen) ──────────────────────────────

  Widget _buildMicInputRow() {
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

        return Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _toggleRecording,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
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
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Shared layout ─────────────────────────────────────────────────────────

  Widget _buildPageContainer({
    required String title,
    required String description,
    required Widget content,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          content,
        ],
      ),
    );
  }

  // ─── MCQ evaluation screen ─────────────────────────────────────────────────

  Widget _buildEvaluationScreen(String feedback, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isCorrect
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect ? Colors.green : Colors.red,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (isCorrect)
            Text(
              '+${_currentPageIndex < widget.level.mcqs.length
                ? _mcqCoinsAwarded[_currentPageIndex]
                : (_evalResult != null
                    ? (_evalResult!.overallScore > 75 ? 10 : (_evalResult!.overallScore > 50 ? 7 : (_evalResult!.overallScore > 30 ? 4 : 1)))
                    : 10)} Coins',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Text(
              feedback,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI response evaluation screen ─────────────────────────────────────────

  Widget _buildResponseEvaluationScreen(DemoEvaluationResult result) {
    final score = result.overallScore;
    final scoreColor = score >= 75
        ? Colors.green
        : score >= 50
            ? AppColors.gold
            : AppColors.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'out of 100',
                  style: TextStyle(
                    color: scoreColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '+${score > 75 ? 10 : (score > 50 ? 7 : (score > 30 ? 4 : 1))} Coins',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sub-scores
          if (result.scores.isNotEmpty) ...[
            _buildScoresRow(result.scores),
            const SizedBox(height: 20),
          ],

          // Feedback
          _buildFeedbackCard(
            label: 'Feedback',
            icon: Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryLight,
            text: result.feedback,
          ),
          const SizedBox(height: 16),

          // Strengths
          if (result.strengths.isNotEmpty)
            _buildBulletCard(
              label: 'Strengths',
              icon: Icons.thumb_up_alt_outlined,
              color: Colors.green,
              items: result.strengths,
            ),
          const SizedBox(height: 16),

          // Improvements
          if (result.improvements.isNotEmpty)
            _buildBulletCard(
              label: 'Areas to Improve',
              icon: Icons.trending_up_rounded,
              color: AppColors.gold,
              items: result.improvements,
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildScoresRow(Map<String, int> scores) {
    return Row(
      children: scores.entries.map((e) {
        final label = e.key[0].toUpperCase() + e.key.substring(1);
        final val = e.value;
        final color = val >= 75
            ? Colors.green
            : val >= 50
                ? AppColors.gold
                : AppColors.error;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                  '$val',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedbackCard({
    required String label,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletCard({
    required String label,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
