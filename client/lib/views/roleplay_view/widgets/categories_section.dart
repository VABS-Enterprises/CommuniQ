import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/all_scenarios_page.dart';

/// The 6 preset keys here must match [_kPresets] in setup_scenario_page.dart.
const _kCategoryItems = [
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
    'key': 'assertiveness',
    'title': 'Technical Solving',
    'subtitle': 'Master logic problems',
    'icon': Icons.code_rounded,
    'colors': [Color(0xFFFF6B35), Color(0xFFFF9A62)],
  },
  {
    'key': 'sales_pitch',
    'title': 'Sales Pitch',
    'subtitle': 'Persuade and close deals',
    'icon': Icons.record_voice_over_rounded,
    'colors': [Color(0xFF7B61FF), Color(0xFF9D7BFF)],
  },
];

class CategoriesSection extends StatelessWidget {
  final String? selectedPresetKey;
  final ValueChanged<String?> onSelect;

  const CategoriesSection({
    super.key,
    required this.selectedPresetKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = _kCategoryItems.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Quick Start',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllScenariosPage()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.primaryLight, size: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            final key = item['key'] as String;
            return _ScenarioCategoryCard(
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              icon: item['icon'] as IconData,
              colors: item['colors'] as List<Color>,
              image: item['image'] as String?,
              isSelected: selectedPresetKey == key,
              onTap: () => onSelect(key),
            );
          },
        ),
      ],
    );
  }
}

class _ScenarioCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String? image;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScenarioCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.image,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[0].withValues(alpha: 0.22),
                    colors[1].withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected ? null : const Color(0xFF0F1520),
          border: Border.all(
            color: isSelected
                ? colors[0].withValues(alpha: 0.5)
                : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colors[0].withValues(alpha: 0.25),
                      colors[1].withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: colors[0].withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: colors[0], size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle.split(' ').take(2).join(' '),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
