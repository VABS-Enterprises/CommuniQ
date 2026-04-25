import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/communiq_level.dart';

class LearningSessionScreen extends StatefulWidget {
  final CommuniqLevel level;
  final bool isAlreadyCompleted;

  const LearningSessionScreen({
    super.key,
    required this.level,
    this.isAlreadyCompleted = false,
  });

  @override
  State<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends State<LearningSessionScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  int _coins = 0;

  // State for each page (0: MCQ, 1: Response)
  // 0 = unsubmitted, 1 = submitted/evaluation
  final List<bool> _isSubmitted = [false, false];

  // MCQ State
  int? _selectedOptionIndex;
  late final List<String> _mcqOptions;
  late final int _correctOptionIndex;
  int _mcqAttempts = 0;
  bool _isMcqWrong = false;

  @override
  void initState() {
    super.initState();
    final options = [
      widget.level.mcqCorrectOption,
      ...widget.level.mcqIncorrectOptions,
    ];
    options.shuffle();
    _correctOptionIndex = options.indexOf(widget.level.mcqCorrectOption);
    _mcqOptions = options;
  }

  // Response State
  bool _isTextResponse = true;
  final TextEditingController _textController = TextEditingController();
  bool _isRecording = false;
  bool _hasRecorded = false;

  void _submitCurrentPage() {
    setState(() {
      if (_currentPageIndex == 0 && _isMcqWrong) {
        _isMcqWrong = false;
        _selectedOptionIndex = null;
        return;
      }

      if (_currentPageIndex == 0) {
        if (_selectedOptionIndex != _correctOptionIndex) {
          _mcqAttempts++;
          _isMcqWrong = true;
          return;
        } else {
          _isSubmitted[0] = true;
          if (!widget.isAlreadyCompleted) {
            int earned = 10 - (_mcqAttempts * 3);
            if (earned < 1) earned = 1;
            _coins += earned;
          }
        }
      } else {
        _isSubmitted[1] = true;
        if (!widget.isAlreadyCompleted) {
          _coins += 10; // 10 coins for the response page
        }
      }
    });
  }

  void _nextPage() {
    if (_currentPageIndex < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Finish the level
      Navigator.pop(context, _coins);
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
    if (_currentPageIndex == 0 && _isMcqWrong) return true; // Allow try again
    if (_isSubmitted[_currentPageIndex]) return false;
    if (_currentPageIndex == 0) return _selectedOptionIndex != null;
    if (_currentPageIndex == 1) {
      return _isTextResponse ? _textController.text.trim().isNotEmpty : _hasRecorded;
    }
    return false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFFFFD700).withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
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
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: List.generate(2, (index) {
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
              physics: const NeverScrollableScrollPhysics(), // Disable swipe to force button usage
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              children: [
                _buildMcqPage(),
                _buildResponsePage(),
              ],
            ),
          ),

          // Bottom Navigation Buttons
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
                // Back Button (Arrow)
                Container(
                  decoration: BoxDecoration(
                    color: ((_currentPageIndex > 0 && _isSubmitted[_currentPageIndex]) || (_currentPageIndex > 0 && _isSubmitted[_currentPageIndex - 1])) 
                        ? Colors.white.withOpacity(0.05) 
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: (_currentPageIndex > 0 && _isSubmitted[_currentPageIndex]) || (_currentPageIndex > 0 && _isSubmitted[_currentPageIndex - 1])
                        ? _prevPage
                        : null,
                    color: Colors.white,
                    disabledColor: Colors.white24,
                  ),
                ),
                
                // Submit Button
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AnimatedBuilder(
                      animation: _textController,
                      builder: (context, _) {
                        return ElevatedButton(
                          onPressed: _canSubmit() ? _submitCurrentPage : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            (_currentPageIndex == 0 && _isMcqWrong) ? 'Try Again' : 'Submit',
                            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Next Button (Arrow)
                Container(
                  decoration: BoxDecoration(
                    color: _isSubmitted[_currentPageIndex]
                        ? AppColors.primaryLight.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _currentPageIndex == 1 
                        ? const Icon(Icons.check_rounded)
                        : const Icon(Icons.arrow_forward_ios_rounded),
                    onPressed: _isSubmitted[_currentPageIndex] ? _nextPage : null,
                    color: _isSubmitted[_currentPageIndex] ? AppColors.primaryLight : Colors.white24,
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
  Widget _buildMcqPage() {
    if (_isSubmitted[0]) return _buildEvaluationScreen(widget.level.mcqCorrectFeedback, true);
    if (_isMcqWrong) return _buildEvaluationScreen(widget.level.mcqIncorrectFeedback, false);

    return _buildPageContainer(
      title: 'Knowledge Check',
      description: widget.level.mcqQuestion.isNotEmpty ? widget.level.mcqQuestion : widget.level.scenario,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(_mcqOptions.length, (index) {
          final isSelected = _selectedOptionIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedOptionIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
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
                        color: isSelected ? AppColors.primary : Colors.white54,
                        width: 2,
                      ),
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _mcqOptions[index],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Response Page ─────────────────────────────────────────────────────────
  Widget _buildResponsePage() {
    if (_isSubmitted[1]) {
      return _buildEvaluationScreen(
        widget.level.responseSuccessFeedback.isNotEmpty 
          ? widget.level.responseSuccessFeedback 
          : 'Great job! Your response was excellent.',
        true
      );
    }

    return _buildPageContainer(
      title: 'Craft Your Response',
      description: widget.level.responsePrompt.isNotEmpty 
          ? widget.level.responsePrompt 
          : 'Choose how you want to answer this scenario:\n\n${widget.level.scenario}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isTextResponse = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isTextResponse ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Type', style: TextStyle(color: _isTextResponse ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isTextResponse = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isTextResponse ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Speak', style: TextStyle(color: !_isTextResponse ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          if (_isTextResponse)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Type your response here...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _isRecording = !_isRecording;
                        if (!_isRecording) {
                          _hasRecorded = true;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isRecording ? 100 : 80,
                      height: _isRecording ? 100 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                        border: Border.all(
                          color: _isRecording ? Colors.redAccent : AppColors.primary,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 40,
                          color: _isRecording ? Colors.redAccent : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isRecording ? 'Recording... Tap to stop' : (_hasRecorded ? 'Recorded! Ready to submit.' : 'Tap to start speaking'),
                    style: TextStyle(
                      color: _isRecording ? Colors.redAccent : Colors.white70,
                      fontSize: 16,
                      fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Shared Layout ─────────────────────────────────────────────────────────
  Widget _buildPageContainer({required String title, required String description, required Widget content}) {
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
              color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, 
              color: isCorrect ? Colors.green : Colors.red, 
              size: 48
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
              '+${_currentPageIndex == 0 ? (10 - (_mcqAttempts * 3) < 1 ? 1 : 10 - (_mcqAttempts * 3)) : 10} Coins',
              style: const TextStyle(
                color: Color(0xFFFFD700),
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
              border: Border.all(color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
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
}
