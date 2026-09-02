import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_conversation_screen.dart';

class FirstRoleplayScreen extends StatelessWidget {
  const FirstRoleplayScreen({super.key});

  static final RoleplayConfig _onboardingConfig = RoleplayConfig(
    scenarioTitle: 'Introduce Yourself',
    scenario: 'Introduce yourself to someone you just met at a networking event.',
    persona: 'Friendly Listener',
    difficulty: 'Easy',
    category: 'Introduction',
    tone: 'Friendly',
    timeLimit: '2 min',
    languageLevel: 'Beginner',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s24),
              _buildProgressDots(2),
              const SizedBox(height: AppSpacing.s32),
              const Text(
                "Let's try your\nfirst roleplay",
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                "You'll have a short conversation with AI",
                style: TextStyle(color: AppColors.inkMuted, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.s28),
              // Info chips row
              Row(
                children: [
                  _buildInfoChip(Icons.mic_none_rounded, 'Speak naturally'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildInfoChip(Icons.sentiment_satisfied_alt_rounded, 'No pressure'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildInfoChip(Icons.timer_outlined, '2 minutes'),
                ],
              ),
              const SizedBox(height: AppSpacing.s28),
              // Module card
              _buildModuleCard(),
              const Spacer(),
              // Primary button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    _slideRoute(
                      RoleplayConversationScreen(
                        config: _onboardingConfig,
                        isOnboarding: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start Roleplay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              // Skip button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    _slideRoute(const SignupScreen()),
                    (_) => false,
                  ),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.brandLight, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT MODULE',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Introduce yourself',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              // Persona chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.face_retouching_natural_rounded,
                        color: AppColors.brandLight, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Friendly Listener',
                      style: TextStyle(
                          color: AppColors.brandLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Text(
                  'Easy',
                  style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildProgressDots(int activeIndex) {
  return Row(
    children: List.generate(
      4,
      (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 6),
        width: i == activeIndex ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == activeIndex ? AppColors.brand : AppColors.outline,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

Route _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}
