import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on CancelledException {
      // dismissed
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return _showError('Please fill in both fields.');
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first, then tap Forgot Password.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordReset(email);
      _showSuccess('Password reset email sent to $email');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: OnboardingBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── Back button row ──────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: AppColors.outline, width: 1),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.ink,
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
                        // Whisperwing, on the bare ground — the gradient
                        // circle and its glow are gone, so the drawn owl is
                        // the only shape here.
                        const Mascot(mood: MascotMood.idle, size: 104),

                        const SizedBox(height: 24),

                        // The gradient ran white -> pale blue, which was
                        // designed against the old dark background. On the
                        // cream ground it painted the headline out entirely.
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [AppColors.brandDark, AppColors.brand],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              // Painted over by the ShaderMask; any opaque
                              // colour works, but keep it readable if the mask
                              // is ever removed.
                              color: AppColors.ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        const Text(
                          'Continue your communication journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

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
                            color: AppColors.surface
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppColors.outline, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
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
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize
                                            .shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AppColors.brandLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
                                  color: AppColors.brand))
                          : OnboardingButton(
                              label: 'Sign In',
                              onPressed: _handleEmailLogin,
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
                            "Don't have an account?  ",
                            style: TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    const SignupScreen(),
                                transitionsBuilder:
                                    (_, anim, __, child) =>
                                        FadeTransition(
                                            opacity: anim,
                                            child: child),
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.brandLight,
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
            color: AppColors.inkMuted,
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
            color: AppColors.ink,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your ${label.toLowerCase()}',
            hintStyle: TextStyle(
                color: AppColors.inkSoft.withValues(alpha: 0.5),
                fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.inkSoft, size: 19),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.inkSoft,
                      size: 19,
                    ),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.outline, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.outline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.brand, width: 1.5),
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
                color: AppColors.outline, thickness: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
        ),
        Expanded(
            child: Divider(
                color: AppColors.outline, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _handleGoogleLogin,
        icon: Image.asset(
          'assets/icons/google_logo.png',
          width: 21,
          height: 21,
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceAlt,
          side: BorderSide(color: AppColors.outline, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
