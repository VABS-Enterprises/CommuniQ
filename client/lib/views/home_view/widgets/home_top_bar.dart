import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/views/auth/screens/login_screen.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.signOut();
      
      // Explicitly navigate back to Login and clear the entire routing stack
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Evening, Alex',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Unlock your communication potential',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        // Icons Row: Logout + Profile
        Row(
          children: [
            // Logout Icon
            GestureDetector(
              onTap: () => _handleLogout(context),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.s8),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Profile Icon
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.s8),
                child: Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
