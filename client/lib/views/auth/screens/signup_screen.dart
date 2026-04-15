import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/auth/screens/login_screen.dart';

class SignupScreen extends StatefulWidget {
  /// Onboarding data collected before authentication.
  /// When provided it is synced to the server immediately after account
  /// creation. If null (e.g. navigated from LoginScreen), any pending local
  /// data is still checked and synced.
  const SignupScreen({super.key, this.onboardingData});

  final OnboardingData? onboardingData;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  /// After successful auth, flush onboarding data to the server.
  /// Uses data passed as a constructor argument first, then falls back to any
  /// data saved locally during the onboarding flow.
  Future<void> _syncOnboarding() async {
    debugPrint('[Auth/Signup] Auth complete — looking for onboarding data to sync...');
    final data = widget.onboardingData ?? await OnboardingService.loadLocal();
    if (data == null) {
      debugPrint('[Auth/Signup] No onboarding data found — skipping sync');
    } else {
      debugPrint('[Auth/Signup] Onboarding data found — syncing to Firestore...');
      await OnboardingService.syncToServer(data);
    }
  }

  Future<void> _handleGoogleSignup() async {
    debugPrint('[Auth/Signup] Google sign-up tapped');
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      debugPrint('[Auth/Signup] ✅ Google sign-up succeeded');
      await _syncOnboarding();
      if (mounted) {
        debugPrint('🎯 [Auth/Signup] ── Popping back to AuthGuard ───────');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on CancelledException {
      debugPrint('[Auth/Signup] Google sign-up cancelled by user');
    } catch (e) {
      debugPrint('[Auth/Signup] ❌ Google sign-up error: $e');
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty) {
      return _showError('Please fill in all fields.');
    }
    if (password.isEmpty || confirmPassword.isEmpty) {
      return _showError('Please enter and confirm your password.');
    }
    if (password.length < 6) {
      return _showError('Password must be at least 6 characters.');
    }
    if (password != confirmPassword) {
      return _showError('Passwords do not match.');
    }

    debugPrint('[Auth/Signup] Email sign-up — registering "$email"');
    setState(() => _isLoading = true);
    try {
      await AuthService.registerWithEmailPassword(name, email, password);
      debugPrint('[Auth/Signup] ✅ Email sign-up succeeded for "$email"');
      await _syncOnboarding();
      if (mounted) {
        debugPrint('🎯 [Auth/Signup] ── Popping back to AuthGuard ───────');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[Auth/Signup] ❌ Email sign-up error: $e');
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Create Account',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start practicing your communication skills today.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),

              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                isPassword: true,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureConfirmPassword,
                isPassword: true,
                isConfirm: true,
              ),

              const SizedBox(height: 36),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : GradientButton(
                      text: 'Create Account',
                      onPressed: _handleEmailSignup,
                    ),

              if (!_isLoading) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: AppColors.border, thickness: 1)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or sign up with',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppColors.border, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _handleGoogleSignup,
                    icon: Image.asset(
                      'assets/icons/google_logo.png',
                      width: 22,
                      height: 22,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.border, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            const LoginScreen(),
                        transitionsBuilder:
                            (_, anim, __, child) =>
                                FadeTransition(
                                    opacity: anim, child: child),
                      ),
                    ),
                    child: const Text('Log in',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    bool isConfirm = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: label == 'Confirm Password'
                ? 'Re-enter your password'
                : 'Enter your ${label.toLowerCase()}',
            hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.5)),
            prefixIcon:
                Icon(icon, color: AppColors.textMuted, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() {
                      if (isConfirm) {
                        _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                      } else {
                        _obscurePassword = !_obscurePassword;
                      }
                    }),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
