import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';
import '../widgets/categories_section.dart';
import '../widgets/roleplay_recent_practice.dart';

class RoleplayView extends StatefulWidget {
  const RoleplayView({super.key});

  @override
  State<RoleplayView> createState() => _RoleplayViewState();
}

class _RoleplayViewState extends State<RoleplayView> {
  String? _selectedPresetKey;

  void _onScenarioSelect(String? key) => setState(
      () => _selectedPresetKey = _selectedPresetKey == key ? null : key);

  void _onStart() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SetupScenarioPage(prefilledPresetKey: _selectedPresetKey),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SkyCampusBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              _buildHeader(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildHeroCard(),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CategoriesSection(
                  selectedPresetKey: _selectedPresetKey,
                  onSelect: _onScenarioSelect,
                ),
              ),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: RoleplayRecentPractice(),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.primaryLight.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'AI POWERED',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Roleplay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Master real conversations with AI',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final isSelected = _selectedPresetKey != null;
    return GestureDetector(
        onTap: _onStart,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSelected
                  ? [
                      const Color(0xFF1C2538),
                      const Color(0xFF0F1520),
                    ]
                  : [
                      const Color(0xFF131B2C),
                      const Color(0xFF1A2438),
                    ],
            ),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelected ? 'Ready to Practice' : 'Custom Roleplay',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSelected
                          ? 'Tap to configure and launch your session'
                          : 'Design any scenario — practice what matters',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primaryExtraLight.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isSelected ? 'Configure & Start →' : 'Start →',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary
                          .withValues(alpha: isSelected ? 0.2 : 0.1),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary
                        .withValues(alpha: isSelected ? 0.4 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: isSelected ? Colors.white : AppColors.primaryLight,
                  size: 38,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
