import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

class CategoriesSection extends StatefulWidget {
  const CategoriesSection({super.key});

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  int _selectedIndex = -1;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Assertiveness', 'icon': Icons.bolt},
    {'title': 'Leadership', 'icon': Icons.groups},
    {'title': 'Negotiation', 'icon': Icons.handshake},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scenarios',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RoleplaySetupScreen(mode: 'custom'),
                ),
              ),
              child: Text(
                'VIEW ALL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.s16),
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  
                  String prefilledScenario = '';
                  String prefilledPersona = 'Friendly Mentor';
                  
                  switch (_categories[index]['title']) {
                    case 'Assertiveness':
                      prefilledScenario = 'Say no politely to extra work';
                      prefilledPersona = 'Strict Boss';
                      break;
                    case 'Leadership':
                      prefilledScenario = 'Guide a struggling team member through a project delay';
                      prefilledPersona = 'Friendly Mentor';
                      break;
                    case 'Negotiation':
                      prefilledScenario = 'Negotiate a larger budget for your department';
                      prefilledPersona = 'Angry Client';
                      break;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoleplaySetupScreen(
                        mode: 'prefilled',
                        scenario: prefilledScenario,
                        persona: prefilledPersona,
                        difficulty: 'Medium',
                        category: _categories[index]['title'],
                      ),
                    ),
                  ).then((_) {
                    if (mounted) setState(() => _selectedIndex = -1);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _categories[index]['icon'],
                        color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                        size: 28,
                      ),
                      const Spacer(),
                      Text(
                        _categories[index]['title'],
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
