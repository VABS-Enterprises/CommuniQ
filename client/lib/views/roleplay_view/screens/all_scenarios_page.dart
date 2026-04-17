import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';

class AllScenariosPage extends StatelessWidget {
  const AllScenariosPage({super.key});

  static const _items = [
    {
      'key': 'assertiveness',
      'title': 'Assertiveness',
      'subtitle': 'Say no politely to extra work',
      'icon': Icons.bolt_rounded,
      'colors': [Color(0xFFFF6B35), Color(0xFFFF9A62)],
    },
    {
      'key': 'job_interview',
      'title': 'Job Interview',
      'subtitle': 'Answer tough HR questions',
      'icon': Icons.work_outline_rounded,
      'colors': [Color(0xFF4FACFE), Color(0xFF00D4FF)],
    },
    {
      'key': 'negotiation',
      'title': 'Negotiation',
      'subtitle': 'Negotiate a raise or budget',
      'icon': Icons.handshake_rounded,
      'colors': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    },
    {
      'key': 'leadership',
      'title': 'Leadership',
      'subtitle': 'Coach a struggling team member',
      'icon': Icons.groups_rounded,
      'colors': [Color(0xFF667EEA), Color(0xFFA78BFA)],
    },
    {
      'key': 'conflict',
      'title': 'Conflict Resolution',
      'subtitle': 'De-escalate a workplace dispute',
      'icon': Icons.balance_rounded,
      'colors': [Color(0xFFFC466B), Color(0xFFFF6B6B)],
    },
    {
      'key': 'small_talk',
      'title': 'Small Talk',
      'subtitle': 'Network at a corporate event',
      'icon': Icons.chat_bubble_outline_rounded,
      'colors': [Color(0xFF7B61FF), Color(0xFF9D7BFF)],
    },
    {
      'key': 'feedback',
      'title': 'Giving Feedback',
      'subtitle': 'Give constructive feedback',
      'icon': Icons.feedback_outlined,
      'colors': [Color(0xFFF7971E), Color(0xFFFFD200)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: Stack(
        children: [
          // Ambient top glow
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) =>
                        _ScenarioCard(item: _items[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF141D2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All Scenarios',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${_items.length} practice scenarios',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ScenarioCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = item['colors'] as List<Color>;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetupScenarioPage(
            prefilledPresetKey: item['key'] as String,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0F1520),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top gradient band
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors[0].withValues(alpha: 0.18),
                      colors[1].withValues(alpha: 0.06),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon in gradient circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors[0].withValues(alpha: 0.25),
                          colors[1].withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors[0].withValues(alpha: 0.3), width: 1),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: colors[0],
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['subtitle'] as String,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
