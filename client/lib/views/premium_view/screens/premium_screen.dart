import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with TickerProviderStateMixin {
  bool _isAnnual = true;

  // Custom premium colors — gold aliases the shared AppColors.gold token so
  // there's one source of truth for the "gold" hex even though this screen's
  // orange/pink/purple accents are a deliberately distinct premium sub-brand.
  static const Color _kPremiumGold = AppColors.gold;
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
    return SkyCampusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
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
    ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Plan: ', style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                Text('Free', style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.bold)),
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
          ),
          child: const Center(
            child: Icon(Icons.workspace_premium_rounded, color: AppColors.inkOnDark, size: 36),
          ),
        ),
        const SizedBox(height: 24),
        // Title
        // The mask ran white -> #E2E2E2, which was designed for the old dark
        // background and rendered the headline invisible on cream.
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.brandDark, AppColors.brand],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'Unlock Your Full\nPotential',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
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
            color: AppColors.inkMuted,
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
          color: isSelected ? AppColors.brand.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.brandLight : AppColors.inkMuted,
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
                child: const Text('SAVE 40%', style: TextStyle(color: AppColors.inkOnDark, fontSize: 10, fontWeight: FontWeight.bold)),
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
          gradient: const LinearGradient(
            colors: [
              AppColors.brandDark,
              AppColors.brand,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              _isAnnual ? 'CommuniQ Premium' : 'CommuniQ Premium',
              style: const TextStyle(color: AppColors.brandLight, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, right: 2),
                  child: Text('\$', style: TextStyle(color: AppColors.inkOnDark, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Text(
                  _isAnnual ? '4.99' : '7.99',
                  style: const TextStyle(color: AppColors.inkOnDark, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isAnnual ? 'per month, billed annually at \$59.88' : 'per month, cancel anytime',
              // Sits on the brand gradient card, so muted grey ink was barely
              // legible — this needs the on-dark ramp, not the on-light one.
              style: const TextStyle(color: AppColors.inkOnDark70, fontSize: 13),
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
          style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.bold),
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
              style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Redirecting to secure checkout...', style: TextStyle(color: AppColors.inkOnDark)),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandDark, AppColors.brand],
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
                  color: AppColors.inkOnDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: AppColors.inkOnDark, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
