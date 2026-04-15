import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with TickerProviderStateMixin {
  bool _isAnnual = true;

  // Custom premium colors
  static const Color _kPremiumGold = Color(0xFFFFD700);
  static const Color _kPremiumOrange = Color(0xFFFF8C00);
  static const Color _kPremiumPink = Color(0xFFFF2A5F);
  static const Color _kPremiumPurple = Color(0xFF9D00FF);
  static const Color _kPremiumCyan = Color(0xFF00D2FF);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Background Ambient Blobs ───
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPremiumPurple.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPremiumCyan.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroHeader(),
                        const SizedBox(height: 32),
                        _buildPricingToggle(),
                        const SizedBox(height: 24),
                        _buildPricingCard(),
                        const SizedBox(height: 32),
                        _buildFeaturesList(),
                        const SizedBox(height: 100), // padding for floating button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Floating Upgrade Button ───
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildUpgradeButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Plan: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('Free', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        // Premium Crown Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_kPremiumOrange, _kPremiumGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPremiumGold.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Center(
            child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 24),
        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE2E2E2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'Unlock Your Full\nPotential',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Master every conversation with advanced AI roleplay scenarios and deeper analytics.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingToggle() {
    return Center(
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(title: 'Monthly', isSelected: !_isAnnual, onTap: () => setState(() => _isAnnual = false)),
            _buildToggleButton(title: 'Annually', isSelected: _isAnnual, showBadge: true, onTap: () => setState(() => _isAnnual = true)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({required String title, required bool isSelected, bool showBadge = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SAVE 40%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child)),
      child: Container(
        key: ValueKey(_isAnnual),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.4),
              _kPremiumPurple.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              _isAnnual ? 'CommuniQ Premium' : 'CommuniQ Premium',
              style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, right: 2),
                  child: Text('\$', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Text(
                  _isAnnual ? '4.99' : '7.99',
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isAnnual ? 'per month, billed annually at \$59.88' : 'per month, cancel anytime',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium Benefits',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(Icons.all_inclusive_rounded, _kPremiumCyan, 'Unlimited roleplay scenarios'),
        _buildFeatureRow(Icons.psychology_rounded, _kPremiumPurple, 'Advanced AI personas & bosses'),
        _buildFeatureRow(Icons.analytics_rounded, _kPremiumOrange, 'Deep conversational analytics & stats'),
        _buildFeatureRow(Icons.speed_rounded, AppColors.success, 'Priority AI generation speed'),
        _buildFeatureRow(Icons.mic_none_rounded, _kPremiumPink, 'Exclusive voice modulations & dialects'),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Redirecting to secure checkout...', style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          // Handle payment integration here
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
        ).copyWith(
          elevation: WidgetStateProperty.all(0),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, _kPremiumPurple],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 56),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
