import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/all_scenarios_page.dart';

class CategoriesSection extends StatelessWidget {
  final Map<String, dynamic>? selectedScenario;
  final ValueChanged<Map<String, dynamic>?> onSelect;

  const CategoriesSection({
    super.key,
    required this.selectedScenario,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> displayedCategories = [
      {'title': 'Assertiveness', 'icon': Icons.bolt, 'scenario': 'Say no politely to extra work', 'persona': 'Strict Boss'},
      {'title': 'Leadership', 'icon': Icons.groups, 'scenario': 'Guide a struggling team member through a project delay', 'persona': 'Friendly Mentor'},
      {'title': 'Negotiation', 'icon': Icons.handshake, 'scenario': 'Negotiate a larger budget for your department', 'persona': 'Angry Client'},
      {'title': 'Small Talk', 'icon': Icons.chat_bubble_outline, 'scenario': 'Network at a corporate event', 'persona': 'Friendly Stranger'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scenarios',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllScenariosPage()),
                );
              },
              child: const Text(
                'View All →',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
            childAspectRatio: 1.1,
          ),
          itemCount: displayedCategories.length,
          itemBuilder: (context, index) {
            final item = displayedCategories[index];
            final isSelected = selectedScenario != null && selectedScenario!['title'] == item['title'];
            return _ScenarioGridCard(
              item: item,
              isSelected: isSelected,
              onTap: () => onSelect(item),
            );
          },
        ),
      ],
    );
  }
}

class _ScenarioGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScenarioGridCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item['icon'],
              color: isSelected ? AppColors.primary : AppColors.primaryLight,
              size: 28,
            ),
            const Spacer(),
            Text(
              item['title'],
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
