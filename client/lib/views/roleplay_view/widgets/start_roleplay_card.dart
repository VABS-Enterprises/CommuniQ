import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class StartRoleplayCard extends StatelessWidget {
  final VoidCallback onStart;
  final bool isCustom;

  const StartRoleplayCard({
    super.key,
    required this.onStart,
    this.isCustom = true,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is superseded by the inline hero card in RoleplayView.
    // Kept for backward compatibility with any older call-sites.
    return GestureDetector(
      onTap: onStart,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1520),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCustom ? 'Custom Roleplay' : 'Start Selected',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCustom
                        ? 'Design your own scenario and start practicing'
                        : 'Configure advanced options or jump right in',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Start →',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primaryLight,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
