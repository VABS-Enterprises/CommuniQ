import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';

class HomeTopBar extends StatelessWidget {
  final UserProfile? profile;
  const HomeTopBar({super.key, this.profile});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final user = AuthService.currentUser;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: (profile?.photoURL != null)
                    ? NetworkImage(profile!.photoURL!)
                    : null,
                child: (profile?.photoURL == null)
                    ? const Icon(Icons.person, color: AppColors.primary, size: 40)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                profile?.name ?? user?.displayName ?? 'User',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                profile?.email ?? user?.email ?? '',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip('Level', '${profile?.level ?? 1}',
                      Icons.military_tech_rounded),
                  _statChip('XP', '${profile?.xp ?? 0}', Icons.bolt_rounded),
                  _statChip('Streak', '${profile?.streak ?? 0}🔥',
                      Icons.local_fire_department_rounded),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleLogout(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Log Out',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final firstName = (profile?.name ?? user?.displayName ?? '').split(' ').first;
    final displayName = firstName.isNotEmpty ? firstName : 'there';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()}, $displayName',
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
        GestureDetector(
          onTap: () => _showProfileSheet(context),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: (profile?.photoURL != null)
                  ? ClipOval(
                      child: Image.network(
                        profile!.photoURL!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 24,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
