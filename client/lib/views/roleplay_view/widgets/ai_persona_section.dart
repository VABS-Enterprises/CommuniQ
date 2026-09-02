import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class AiPersonaSection extends StatefulWidget {
  final String initialPersona;
  final ValueChanged<String>? onChanged;

  const AiPersonaSection({
    super.key,
    this.initialPersona = 'Strict Boss',
    this.onChanged,
  });

  @override
  State<AiPersonaSection> createState() => _AiPersonaSectionState();
}

class _AiPersonaSectionState extends State<AiPersonaSection> {
  late int _selectedIndex;

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
    {
      'name': 'Friendly Mentor',
      'label': 'SUPPORTIVE',
      'icon': Icons.psychology_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = _personas.indexWhere(
        (p) => p['name'] == widget.initialPersona);
    if (_selectedIndex == -1) _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Persona',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
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
                  widget.onChanged?.call(_personas[index]['name'] as String);
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
                      color: isSelected ? AppColors.brand : AppColors.outline,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: 0.1),
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
                          color: AppColors.bg,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brand.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _personas[index]['icon'] as IconData,
                          color: isSelected ? AppColors.brandLight : AppColors.inkSoft,
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
                              _personas[index]['name'] as String,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _personas[index]['label'] as String,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isSelected
                                        ? AppColors.brandLight
                                        : AppColors.inkSoft,
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
