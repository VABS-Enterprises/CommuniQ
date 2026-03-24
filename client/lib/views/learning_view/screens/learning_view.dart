import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

class LearningView extends StatelessWidget {
  const LearningView({super.key});

  static const List<Map<String, dynamic>> _topics = [
    {
      'title': 'Assertiveness',
      'subtitle': 'Stand your ground with confidence',
      'icon': Icons.bolt_rounded,
      'scenario': 'Say no politely to extra work',
      'persona': 'Strict Boss',
      'category': 'Assertiveness',
    },
    {
      'title': 'Negotiation',
      'subtitle': 'Win-win outcomes every time',
      'icon': Icons.handshake_rounded,
      'scenario': 'Negotiate a larger budget for your department',
      'persona': 'Angry Client',
      'category': 'Negotiation',
    },
    {
      'title': 'Leadership',
      'subtitle': 'Inspire and guide your team',
      'icon': Icons.groups_rounded,
      'scenario': 'Guide a struggling team member through a project delay',
      'persona': 'Friendly Mentor',
      'category': 'Leadership',
    },
    {
      'title': 'Public Speaking',
      'subtitle': 'Captivate any audience',
      'icon': Icons.record_voice_over_rounded,
      'scenario': 'Deliver a confident opening statement to a group',
      'persona': 'Friendly Mentor',
      'category': 'Public Speaking',
    },
    {
      'title': 'Interview Prep',
      'subtitle': 'Nail every question with ease',
      'icon': Icons.work_outline_rounded,
      'scenario': 'Answer "Tell me about yourself" in a job interview',
      'persona': 'Strict Boss',
      'category': 'Interview',
    },
    {
      'title': 'Conflict Resolution',
      'subtitle': 'Turn tension into agreement',
      'icon': Icons.balance_rounded,
      'scenario': 'Resolve a disagreement with a difficult colleague',
      'persona': 'Angry Client',
      'category': 'Conflict',
    },
  ];

  static const List<String> _tips = [
    'Pause before responding — silence is not weakness, it is composure.',
    'Use "I" statements to express feelings without sounding accusatory.',
    'Mirror the other person\'s body language to build instant rapport.',
    'Ask open-ended questions to keep the conversation flowing naturally.',
    'Repeat the key points you heard before responding — it shows you listened.',
    'Slow your speech rate by 20% when making an important point.',
    'Name the emotion you are observing: "It sounds like you\'re frustrated." It defuses tension.',
  ];

  String _getDailyTip() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _tips[dayOfYear % _tips.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildDailyTip(context),
                const SizedBox(height: 32),
                _buildTopicsSection(context),
                const SizedBox(height: 32),
                _buildComingSoon(context),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNIQ HUB',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Level Up Your\nCommunication',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Practice scenarios designed to sharpen real-world skills.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildDailyTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY TIP',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getDailyTip(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Topics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a topic to start a guided roleplay session.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _topics.length,
          itemBuilder: (context, index) => _buildTopicCard(context, _topics[index]),
        ),
      ],
    );
  }

  Widget _buildTopicCard(BuildContext context, Map<String, dynamic> topic) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplaySetupScreen(
            mode: 'prefilled',
            scenario: topic['scenario'] as String,
            persona: topic['persona'] as String,
            difficulty: 'Medium',
            category: topic['category'] as String,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                topic['icon'] as IconData,
                color: AppColors.primaryLight,
                size: 22,
              ),
            ),
            const Spacer(),
            Text(
              topic['title'] as String,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              topic['subtitle'] as String,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoon(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coming Soon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildComingSoonCard(
          context,
          icon: Icons.quiz_rounded,
          title: 'Interactive Exercises',
          description: 'Bite-sized drills to sharpen specific communication skills.',
        ),
        const SizedBox(height: 12),
        _buildComingSoonCard(
          context,
          icon: Icons.menu_book_rounded,
          title: 'Vocabulary Builder',
          description: 'Expand your professional vocabulary with daily word challenges.',
        ),
        const SizedBox(height: 12),
        _buildComingSoonCard(
          context,
          icon: Icons.insights_rounded,
          title: 'Progress Analytics',
          description: 'Deep-dive reports tracking your improvement over time.',
        ),
      ],
    );
  }

  Widget _buildComingSoonCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This feature is coming soon!'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        'SOON',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
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
