import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  void _onTap(BuildContext context, String label) {
    switch (label) {
      case 'Roleplay':
        SwitchToRoleplayTabNotification().dispatch(context);
      case 'Learn':
        SwitchToLearningTabNotification().dispatch(context);
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label — Coming Soon!'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(context, 'Roleplay', Icons.mic),
        _buildActionItem(context, 'Practice', Icons.chat_bubble_outline),
        _buildActionItem(context, 'Learn', Icons.menu_book),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, String label, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: GestureDetector(
          onTap: () => _onTap(context, label),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dispatched when the user taps the "Roleplay" quick action.
/// Caught by [MainNavigationView] to switch to tab index 2.
class SwitchToRoleplayTabNotification extends Notification {}

/// Dispatched when the user taps the "Learn" quick action.
/// Caught by [MainNavigationView] to switch to tab index 1.
class SwitchToLearningTabNotification extends Notification {}

/// Dispatched when the user taps the profile avatar.
/// Caught by [MainNavigationView] to switch to tab index 3.
class SwitchToProfileTabNotification extends Notification {}
