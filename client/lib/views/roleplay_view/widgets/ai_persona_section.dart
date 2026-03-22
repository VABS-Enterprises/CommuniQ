import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class AiPersonaSection extends StatefulWidget {
  const AiPersonaSection({super.key});

  @override
  State<AiPersonaSection> createState() => _AiPersonaSectionState();
}

class _AiPersonaSectionState extends State<AiPersonaSection> {
  int _selectedIndex = 0; // Strict Boss selected by default

  final List<Map<String, dynamic>> _personas = [
    {
      'name': 'Strict Boss',
      'label': 'HIGH PRESSURE',
      'icon': Icons.person,
    },
    {
      'name': 'Angry Client',
      'label': 'EMOTIONAL',
      'icon': Icons.sentiment_dissatisfied,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Persona',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _personas.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.s16),
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                          border: Border.all(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _personas[index]['icon'],
                          color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _personas[index]['name'],
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _personas[index]['label'],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                                    fontSize: 8,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
