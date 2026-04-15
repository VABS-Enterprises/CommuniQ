import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/views/contest_view/screens/contest_page.dart';

class ContestEntryPage extends StatelessWidget {
  const ContestEntryPage({super.key});

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Coming Soon 🚀',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "We're working on this feature. Stay tuned!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                '🏆 Contest Arena',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your challenge',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              
              // Daily Contest
              _ContestTypeCard(
                title: 'Daily Contest',
                subtitle: 'Quick daily speaking challenge',
                tagText: 'Coming Soon',
                isInactive: true,
                onTap: () => _showComingSoon(context),
              ),
              
              const SizedBox(height: 20),
              
              // Weekly Contest (Active)
              _ContestTypeCard(
                title: 'Weekly Contest',
                subtitle: 'Compete and climb leaderboard',
                tagText: 'Active',
                isActive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContestPage()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Monthly Contest
              _ContestTypeCard(
                title: 'Monthly Contest',
                subtitle: 'Long-term competition',
                tagText: 'Coming Soon',
                isInactive: true,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContestTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tagText;
  final bool isInactive;
  final bool isActive;
  final VoidCallback onTap;

  const _ContestTypeCard({
    required this.title,
    required this.subtitle,
    required this.tagText,
    this.isInactive = false,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? AppColors.primary.withValues(alpha: 0.5) 
                : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive ? AppGlow.magentaGlow(blurRadius: 16, spreadRadius: 1) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isInactive ? AppColors.textSecondary : AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isInactive) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock, size: 16, color: AppColors.textMuted),
                      ]
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isInactive ? AppColors.textMuted : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? AppColors.primary.withValues(alpha: 0.2) 
                          : AppColors.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive 
                            ? AppColors.primary.withValues(alpha: 0.4) 
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      tagText,
                      style: TextStyle(
                        color: isActive ? AppColors.primaryLight : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isInactive ? AppColors.textMuted : AppColors.primaryLight,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
