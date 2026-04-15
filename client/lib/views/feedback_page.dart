import 'package:flutter/material.dart';
import 'dart:math' as math;

class FeedbackPage extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? feedbackData;

  const FeedbackPage({
    Key? key,
    required this.sessionId,
    this.feedbackData,
  }) : super(key: key);

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with TickerProviderStateMixin {
  late Map<String, dynamic> feedback;
  late AnimationController _scoreAnimationController;
  late Animation<double> _scoreAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    try {
      feedback = widget.feedbackData ?? _getMockFeedbackData();

      _scoreAnimationController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );

      _scoreAnimation = Tween<double>(begin: 0, end: feedback['score'] / 100)
          .animate(CurvedAnimation(
              parent: _scoreAnimationController, curve: Curves.easeOut));

      _scoreAnimationController.forward();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing feedback: $e');
    }
  }

  @override
  void dispose() {
    _scoreAnimationController.dispose();
    super.dispose();
  }

  static Map<String, dynamic> _getMockFeedbackData() {
    return {
      'score': 78,
      'aiSummary': 'You communicated clearly but hesitated during key moments',
      'talkRatio': {'userSpoke': 68, 'aiSpoke': 32},
      'responseTime': {'average': 2.3, 'status': 'Normal'},
      'interruptions': 3,
      'pauses': {'level': 'High', 'status': '⚠️'},
      'clarity': 'Good',
      'fillerWords': {
        'total': 12,
        'previousTotal': 18,
        'words': [
          {'word': 'um', 'count': 5},
          {'word': 'like', 'count': 3},
          {'word': 'uh', 'count': 2},
          {'word': 'you know', 'count': 2},
        ],
        'exampleSentence':
            'I was [um] thinking that [like] we can [uh] improve the system',
      },
      'skills': {
        'confidence': 65,
        'clarity': 82,
        'fluency': 78,
      },
      'improvements': [
        {'skill': 'Confidence', 'change': 10},
        {'skill': 'Fluency', 'change': 6},
      ],
      'aiSuggestion':
          'You hesitate before answering. Start with a strong first sentence.',
      'nextPractice': 'Handle follow-up interview questions',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C5CFF)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Complete',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your Feedback',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Score Card
                    _ScoreCard(scoreAnimation: _scoreAnimation, score: feedback['score']),
                    const SizedBox(height: 24),
                    // AI Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        feedback['aiSummary'],
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 14,
                          height: 1.7,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Conversation Analysis
                    _SectionTitle(title: 'Conversation Analysis'),
                    const SizedBox(height: 12),
                    _AnalysisCard(
                      children: [
                        _MetricRow(
                          label: 'Talk Ratio',
                          value:
                              '${feedback['talkRatio']['userSpoke']}% / ${feedback['talkRatio']['aiSpoke']}%',
                          progressValue:
                              feedback['talkRatio']['userSpoke'] / 100,
                        ),
                        _Divider(),
                        _MetricRow(
                          label: 'Response Time',
                          value: '${feedback['responseTime']['average']}s',
                          status: feedback['responseTime']['status'],
                        ),
                        _Divider(),
                        _MetricRow(
                          label: 'Interruptions',
                          value: '${feedback['interruptions']}',
                          sublabel: 'times',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Speech Quality
                    _SectionTitle(title: 'Speech Quality'),
                    const SizedBox(height: 12),
                    _AnalysisCard(
                      children: [
                        _QualityMetric(
                          label: 'Long Pauses',
                          status:
                              '${feedback['pauses']['level']} ${feedback['pauses']['status']}',
                          statusColor: const Color(0xFFFF6B6B),
                        ),
                        _Divider(),
                        _QualityMetric(
                          label: 'Sentence Clarity',
                          status: '${feedback['clarity']}',
                          statusColor: const Color(0xFF51CF66),
                          icon: Icons.check_circle_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Filler Words
                    _SectionTitle(title: 'Filler Words'),
                    const SizedBox(height: 12),
                    _FillerWordsCard(fillerWords: feedback['fillerWords']),
                    const SizedBox(height: 28),
                    // Skills
                    _SectionTitle(title: 'Communication Skills'),
                    const SizedBox(height: 12),
                    _SkillsCard(skills: feedback['skills']),
                    const SizedBox(height: 28),
                    // Improvements
                    _SectionTitle(title: 'Your Improvements'),
                    const SizedBox(height: 12),
                    Column(
                      spacing: 10,
                      children: (feedback['improvements']
                              as List<Map<String, dynamic>>)
                          .map((imp) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF51CF66).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF51CF66).withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                imp['skill'],
                                style: const TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFF51CF66),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+${imp['change']}%',
                                    style: const TextStyle(
                                      color: Color(0xFF51CF66),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    // AI Tip
                    _SectionTitle(title: 'AI Coach Tip'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5CFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7C5CFF).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFFA78BBA),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feedback['aiSuggestion'],
                              style: const TextStyle(
                                color: Color(0xFFC9B8FF),
                                fontSize: 13,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Next Practice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF7C5CFF).withOpacity(0.15),
                            const Color(0xFFA78BBA).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7C5CFF).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 240,
                                child: Text(
                                  feedback['nextPractice'],
                                  style: const TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C5CFF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFA78BBA),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF7C5CFF).withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Try Again',
                            style: TextStyle(
                              color: Color(0xFF7C5CFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF7C5CFF),
                              Color(0xFFA78BBA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C5CFF).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Next Practice',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
class _ScoreCard extends StatelessWidget {
  final Animation<double> scoreAnimation;
  final int score;

  const _ScoreCard({
    required this.scoreAnimation,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7C5CFF).withOpacity(0.15),
            const Color(0xFFA78BBA).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 8,
                    ),
                  ),
                ),
                // Animated progress ring
                AnimatedBuilder(
                  animation: scoreAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(130, 130),
                      painter: _ScoreRingPainter(scoreAnimation.value),
                    );
                  },
                ),
                // Score text
                Center(
                  child: AnimatedBuilder(
                    animation: scoreAnimation,
                    builder: (context, child) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(scoreAnimation.value * score).toInt()}',
                            style: const TextStyle(
                              color: Color(0xFFA78BBA),
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Score',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Analysis Card
class _AnalysisCard extends StatelessWidget {
  final List<Widget> children;

  const _AnalysisCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// Metric Row
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double? progressValue;
  final String? status;
  final String? sublabel;

  const _MetricRow({
    required this.label,
    required this.value,
    this.progressValue,
    this.status,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (status != null)
                Text(
                  status!,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (progressValue != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF7C5CFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Quality Metric
class _QualityMetric extends StatelessWidget {
  final String label;
  final String status;
  final Color statusColor;
  final IconData? icon;

  const _QualityMetric({
    required this.label,
    required this.status,
    required this.statusColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  icon,
                  color: statusColor,
                  size: 16,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Divider
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Colors.white.withOpacity(0.08),
        height: 1,
      ),
    );
  }
}

// Filler Words Card
class _FillerWordsCard extends StatelessWidget {
  final Map<String, dynamic> fillerWords;

  const _FillerWordsCard({required this.fillerWords});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        spacing: 16,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Color(0xFFFF6B6B), size: 16),
                const SizedBox(width: 8),
                Text(
                  '${fillerWords['total']} filler words found',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            spacing: 8,
            children: (fillerWords['words'] as List<Map<String, dynamic>>)
                .map((w) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '"${w['word']}"',
                    style: const TextStyle(
                      color: Color(0xFFA78BBA),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${w['count']}x',
                      style: const TextStyle(
                        color: Color(0xFFA78BBA),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child:
                _HighlightedSentence(sentence: fillerWords['exampleSentence']),
          ),
        ],
      ),
    );
  }
}

// Skills Card
class _SkillsCard extends StatelessWidget {
  final Map<String, int> skills;

  const _SkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        spacing: 14,
        children: skills.entries.map((entry) {
          return _SkillMetric(label: entry.key, value: entry.value);
        }).toList(),
      ),
    );
  }
}

// Skill Metric
class _SkillMetric extends StatelessWidget {
  final String label;
  final int value;

  const _SkillMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value%',
              style: const TextStyle(
                color: Color(0xFFA78BBA),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFFA78BBA),
            ),
          ),
        ),
      ],
    );
  }
}

// Section Title
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// Highlighted Sentence
class _HighlightedSentence extends StatelessWidget {
  final String sentence;

  const _HighlightedSentence({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final parts = sentence.split(RegExp(r'(\[.*?\])'));

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: parts.map((part) {
        if (part.startsWith('[') && part.endsWith(']')) {
          final word = part.replaceAll(RegExp(r'[\[\]]'), '');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              word,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        } else {
          return Text(
            part,
            style: const TextStyle(
              color: Color(0xFFBDBEC3),
              fontSize: 12,
              height: 1.6,
            ),
          );
        }
      }).toList(),
    );
  }
}

// Score Ring Painter
class _ScoreRingPainter extends CustomPainter {
  final double progress;

  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final paint = Paint()
      ..color = const Color(0xFF7C5CFF)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
