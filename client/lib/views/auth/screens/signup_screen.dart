import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/auth/screens/login_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class SignupScreen extends StatefulWidget {
  /// Onboarding data collected before authentication.
  /// When provided it is synced to the server immediately after account
  /// creation. If null, any pending locally-saved data is checked and synced.
  const SignupScreen({super.key, this.onboardingData});

  final OnboardingData? onboardingData;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _entranceCtrl;
  late Animation<double> _fadeTop;
  late Animation<Offset> _slideTop;
  late Animation<double> _fadeCard;
  late Animation<Offset> _slideCard;
  late Animation<double> _fadeBottom;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeTop = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _slideTop = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _fadeCard = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOut));
    _slideCard = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 0.75, curve: Curves.easeOut)));
    _fadeBottom = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _syncOnboarding() async {
    final data = widget.onboardingData ?? await OnboardingService.loadLocal();
    if (data != null) await OnboardingService.syncToServer(data);
  }

  Future<void> _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      await _syncOnboarding();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on CancelledException {
      // dismissed
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty) {
      return _showError('Please fill in all fields.');
    }
    if (password.isEmpty) {
      return _showError('Please enter your password.');
    }
    if (password.length < 6) {
      return _showError('Password must be at least 6 characters.');
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.registerWithEmailPassword(name, email, password);
      await _syncOnboarding();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── Back button ──────────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: AppColors.glassBorder, width: 1),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Logo + headline ──────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeTop,
                  child: SlideTransition(
                    position: _slideTop,
                    child: Column(
                      children: [
                        // Glowing logo circle
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.45),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: AppColors.violet
                                    .withValues(alpha: 0.25),
                                blurRadius: 60,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/hummingbird.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Create account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your personalized plan is ready — sign up to unlock it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Glass form card ──────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeCard,
                  child: SlideTransition(
                    position: _slideCard,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppColors.glassBorder, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              _buildField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 18),
                              _buildField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType:
                                    TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 18),
                              _buildField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                isPassword: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── CTA + socials ────────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeBottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary))
                          : OnboardingButton(
                              label: 'Create Account',
                              onPressed: _handleEmailSignup,
                            ),

                      if (!_isLoading) ...[
                        const SizedBox(height: 28),
                        _buildDivider(),
                        const SizedBox(height: 28),
                        _buildGoogleButton(),
                      ],

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?  ',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    const LoginScreen(),
                                transitionsBuilder:
                                    (_, anim, __, child) =>
                                        FadeTransition(
                                            opacity: anim,
                                            child: child),
                              ),
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your ${label.toLowerCase()}',
            hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.5),
                fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 19),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 19,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.glassBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.glassBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: AppColors.glassBorder, thickness: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
        Expanded(
            child: Divider(
                color: AppColors.glassBorder, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _handleGoogleSignup,
        icon: Image.asset(
          'assets/icons/google_logo.png',
          width: 21,
          height: 21,
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          side: BorderSide(color: AppColors.glassBorder, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
