import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';

class AllScenariosPage extends StatelessWidget {
  const AllScenariosPage({super.key});

  static const _items = [
    {
      'key': 'job_interview',
      'title': 'Job Interview',
      'subtitle': 'Answer tough HR questions',
      'icon': Icons.work_outline_rounded,
      'colors': [Color(0xFF4FACFE), Color(0xFF00D4FF)],
      'image': 'assets/images/scenarios/job_interview_v2.png',
    },
    {
      'key': 'negotiation',
      'title': 'Negotiation',
      'subtitle': 'Negotiate a raise or budget',
      'icon': Icons.handshake_rounded,
      'colors': [Color(0xFF43E97B), Color(0xFF38F9D7)],
      'image': 'assets/images/scenarios/negotiation_v2.png',
    },
    {
      'key': 'assertiveness',
      'title': 'Technical Problem',
      'subtitle': 'Solve coding challenges',
      'icon': Icons.code_rounded,
      'colors': [Color(0xFFFF6B35), Color(0xFFFF9A62)],
      'image': 'assets/images/scenarios/technical_solving.png',
    },
    {
      'key': 'small_talk',
      'title': 'Sales Pitch',
      'subtitle': 'Network and sell your idea',
      'icon': Icons.record_voice_over_rounded,
      'colors': [Color(0xFF7B61FF), Color(0xFF9D7BFF)],
      'image': 'assets/images/scenarios/sales_pitch.png',
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
                      childAspectRatio: 0.78,
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
    final hasImage = item.containsKey('image');

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
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFF0F1520),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Circular Image Frame
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasImage
                      ? Image.asset(
                          item['image'] as String,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(item['icon'] as IconData,
                              color: AppColors.primaryLight, size: 40),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Text Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['subtitle'] as String,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
