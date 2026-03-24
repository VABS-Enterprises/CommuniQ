import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class DifficultySection extends StatefulWidget {
  final String initialDifficulty;
  final ValueChanged<String>? onChanged;

  const DifficultySection({
    super.key,
    this.initialDifficulty = 'Medium',
    this.onChanged,
  });

  @override
  State<DifficultySection> createState() => _DifficultySectionState();
}

class _DifficultySectionState extends State<DifficultySection> {
  late int _selectedIndex;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Nightmare'];

  @override
  void initState() {
    super.initState();
    _selectedIndex = _difficulties.indexOf(widget.initialDifficulty);
    if (_selectedIndex == -1) _selectedIndex = 1; // default Medium
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Difficulty',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: List.generate(
            _difficulties.length,
            (index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  widget.onChanged?.call(_difficulties[index]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _difficulties[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
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
