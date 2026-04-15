import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: AppGlow.mixedGlow(blurRadius: 18, spreadRadius: 2),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCustom ? 'Custom Roleplay' : 'Start Selected',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.55,
                child: Text(
                  isCustom 
                      ? 'Create your own scenario and start practicing'
                      : 'Configure advanced options or jump right in',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(120, 44),
                  elevation: 0,
                ),
                child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                color: AppColors.primaryLight,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
