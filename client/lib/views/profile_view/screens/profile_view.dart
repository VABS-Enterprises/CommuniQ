import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  UserProfile? _profile;
  OnboardingData? _onboarding;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = false; });
    try {
      final profile = await SessionService.instance.fetchProfile();
      OnboardingData? onboarding;
      try {
        final res = await ApiService.instance.dio.get(ApiConstants.onboarding);
        final raw = (res.data as Map<String, dynamic>?)?['onboarding'];
        if (raw != null) {
          onboarding = OnboardingData.fromJson(raw as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('[ProfileView] Onboarding fetch skipped: $e');
      }
      if (mounted) setState(() { _profile = profile; _onboarding = onboarding; _loading = false; });
    } catch (e) {
      debugPrint('[ProfileView] load failed: $e');
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.signOut();
    }
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(color: AppColors.textSecondary, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildStatsRow()),
                        SliverToBoxAdapter(child: _buildXpBar()),
                        if (_onboarding != null)
                          SliverToBoxAdapter(child: _buildOnboardingSection()),
                        SliverToBoxAdapter(child: _buildSection(
                          'Account',
                          [
                            _buildTile(Icons.person_outline_rounded, 'Display Name',
                                subtitle: _profile?.name ?? '—'),
                            _buildTile(Icons.email_outlined, 'Email',
                                subtitle: _profile?.email ?? '—',
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _profile?.email ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Email copied to clipboard')),
                                  );
                                }),
                            _buildTile(
                              _profile?.isPremium == true
                                  ? Icons.workspace_premium_rounded
                                  : Icons.stars_outlined,
                              'Plan',
                              subtitle: _profile?.isPremium == true ? 'Premium' : 'Free',
                              trailingColor: _profile?.isPremium == true
                                  ? const Color(0xFFFFD700)
                                  : AppColors.textMuted,
                            ),
                          ],
                        )),
                        SliverToBoxAdapter(child: _buildSection(
                          'Legal',
                          [
                            _buildTile(Icons.description_outlined, 'Terms & Conditions',
                                onTap: () => _showInfoDialog(
                                    'Terms & Conditions', _kTerms)),
                            _buildTile(Icons.privacy_tip_outlined, 'Privacy Policy',
                                onTap: () => _showInfoDialog(
                                    'Privacy Policy', _kPrivacy)),
                          ],
                        )),
                        SliverToBoxAdapter(child: _buildSection(
                          'App',
                          [
                            _buildTile(Icons.info_outline_rounded, 'App Version',
                                subtitle: '1.0.0 (build 1)'),
                            _buildTile(Icons.help_outline_rounded, 'Help & Support',
                                onTap: () => _showInfoDialog(
                                    'Help & Support',
                                    'For support, reach us at support@communiq.app')),
                          ],
                        )),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout_rounded,
                                    color: Colors.redAccent, size: 20),
                                label: const Text('Log Out',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                onPressed: _handleLogout,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // bottom padding for nav bar
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Could not load profile',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _load,
            child: const Text('Retry', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final user = AuthService.currentUser;
    final name = _profile?.name ?? user?.displayName ?? 'User';
    final email = _profile?.email ?? user?.email ?? '';
    final photo = _profile?.photoURL ?? user?.photoURL;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.transparent,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                if (_profile?.isPremium == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Premium',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('Free Plan',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final lvl = _profile?.level ?? 1;
    final xp = _profile?.xp ?? 0;
    final streak = _profile?.streak ?? 0;
    final badges = _profile?.badges.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('Level', '$lvl', Icons.military_tech_rounded,
              const Color(0xFF7C5CFF)),
          const SizedBox(width: 10),
          _statCard('XP', '$xp', Icons.bolt_rounded,
              const Color(0xFFFBBF24)),
          const SizedBox(width: 10),
          _statCard('Streak', '$streak 🔥', Icons.local_fire_department_rounded,
              const Color(0xFFEF4444)),
          const SizedBox(width: 10),
          _statCard('Badges', '$badges', Icons.workspace_premium_rounded,
              const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── XP progress bar ───────────────────────────────────────────────────────

  Widget _buildXpBar() {
    final progress = _profile?.xpProgress ?? 0.0;
    final toNext = _profile?.xpToNextLevel ?? 0;
    final level = _profile?.level ?? 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Level $level Progress',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(toNext > 0 ? '$toNext XP to next level' : 'Max level!',
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onboarding section ────────────────────────────────────────────────────

  Widget _buildOnboardingSection() {
    final o = _onboarding!;
    return _buildSection(
      'Onboarding Preferences',
      [
        if (o.contexts.isNotEmpty)
          _buildChipTile(Icons.place_outlined, 'Communication Contexts', o.contexts),
        if (o.challenges.isNotEmpty)
          _buildChipTile(Icons.psychology_outlined, 'Challenges', o.challenges),
        if (o.speakingStyle != null)
          _buildTile(Icons.record_voice_over_outlined, 'Speaking Style',
              subtitle: o.speakingStyle!),
        if (o.level != null)
          _buildTile(Icons.signal_cellular_alt_rounded, 'Skill Level',
              subtitle: o.level!),
        if (o.primaryGoal != null)
          _buildTile(Icons.flag_outlined, 'Primary Goal',
              subtitle: o.primaryGoal!),
        if (o.speakingNote != null && o.speakingNote!.isNotEmpty)
          _buildTile(Icons.notes_rounded, 'Personal Note',
              subtitle: o.speakingNote!),
      ],
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5),
                        indent: 50),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    Color? trailingColor,
  }) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded,
              color: trailingColor ?? AppColors.textMuted, size: 20)
          : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _buildChipTile(IconData icon, String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: items
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static legal text ─────────────────────────────────────────────────────

const String _kTerms = '''
Last updated: March 2026

1. Acceptance of Terms
By accessing or using CommuniQ, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.

2. Use of the App
CommuniQ is provided for personal, non-commercial use. You agree not to misuse the platform, including but not limited to attempting to reverse-engineer, disrupt, or compromise the service.

3. User Accounts
You are responsible for maintaining the confidentiality of your account credentials. You agree to notify us immediately of any unauthorized use of your account.

4. Content
All AI-generated content within the app is for practice and educational purposes only. CommuniQ does not guarantee the accuracy or fitness of any generated content for specific situations.

5. Limitation of Liability
CommuniQ is provided "as is" without warranties of any kind. We are not liable for any indirect, incidental, or consequential damages arising from your use of the app.

6. Changes to Terms
We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the updated terms.

7. Contact
For questions regarding these terms, contact us at legal@communiq.app.
''';

const String _kPrivacy = '''
Last updated: March 2026

1. Information We Collect
We collect information you provide directly (name, email) and data generated through your use of the app (session history, onboarding preferences, XP, streak).

2. How We Use Your Information
Your data is used to personalise your experience, track progress, and improve the service. We do not sell your personal information to third parties.

3. Data Storage
Your data is securely stored using Google Firebase (Firestore and Authentication). We implement industry-standard security measures to protect your information.

4. Third-Party Services
CommuniQ uses Google Sign-In for authentication and Firebase for backend services. These services have their own privacy policies.

5. Data Retention
You may delete your account at any time. Upon deletion, your personal data will be removed from our systems within 30 days.

6. Your Rights
You have the right to access, correct, or delete your personal data. Contact us at privacy@communiq.app to exercise these rights.

7. Contact
For privacy concerns, reach us at privacy@communiq.app.
''';
