import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/premium_view/screens/premium_screen.dart';

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
  bool _trainingOptedIn = true;
  bool _trainingConsentUpdating = false;

  StreamSubscription<UserProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Update silently when background refresh completes.
    _profileSub = SessionService.instance.profileUpdates.listen((fresh) {
      if (mounted) setState(() { _profile = fresh; _error = false; });
    });
    _load();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        // Only show spinner on first load when there's no cached data.
        if (_profile == null) _loading = true;
        _error = false;
      });
    }
    try {
      final profile = forceRefresh
          ? await SessionService.instance.refreshProfile()
          : await SessionService.instance.fetchProfile();
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
      bool trainingOptedIn = _trainingOptedIn;
      try {
        final res =
            await ApiService.instance.dio.get(ApiConstants.userEvaluationProfile);
        final consent =
            (res.data as Map<String, dynamic>?)?['trainingConsent'] as Map<String, dynamic>?;
        if (consent != null && consent['optedIn'] is bool) {
          trainingOptedIn = consent['optedIn'] as bool;
        }
      } catch (e) {
        debugPrint('[ProfileView] Training consent fetch skipped: $e');
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _onboarding = onboarding;
          _trainingOptedIn = trainingOptedIn;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileView] load failed: $e');
      if (mounted) {
        setState(() {
          // Only show the error screen if we have no data at all to show.
          if (_profile == null) _error = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Text('Log Out', style: AppTextStyles.titleLarge),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log Out',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.signOut();
    }
  }

  Future<void> _updateTrainingConsent(bool optedIn) async {
    final previous = _trainingOptedIn;
    setState(() {
      _trainingOptedIn = optedIn;
      _trainingConsentUpdating = true;
    });
    try {
      await ApiService.instance.dio.patch(
        ApiConstants.userTrainingConsent,
        data: {'optedIn': optedIn},
      );
    } catch (e) {
      debugPrint('[ProfileView] Training consent update failed: $e');
      if (mounted) {
        setState(() => _trainingOptedIn = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your preference. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _trainingConsentUpdating = false);
    }
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Text(title, style: AppTextStyles.titleLarge),
        content: SingleChildScrollView(
          child: Text(body, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.brand)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 2,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: SafeArea(
          child: _loading
              ? const LoadingStateView()
              : _error
                  ? ErrorStateView(
                      title: 'Could not load profile',
                      message:
                          'Your account may not exist yet, or the server is unreachable.',
                      onRetry: () => _load(forceRefresh: true),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(forceRefresh: true),
                      color: AppColors.brand,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          AppSpacing.s12,
                          AppSpacing.page,
                          AppSpacing.navClearance,
                        ),
                        children: [
                          _ProfileHeroHeader(profile: _profile),
                          const SizedBox(height: AppSpacing.section),

                          if (_profile?.isPremium != true) ...[
                            _PremiumBanner(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PremiumScreen()),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.section),
                          ],

                          if (_onboarding != null) ...[
                            _OnboardingSection(onboarding: _onboarding!),
                            const SizedBox(height: AppSpacing.section),
                          ],

                          _buildSection('Account', [
                            _Tile(
                              icon: Icons.person_outline_rounded,
                              title: 'Display Name',
                              subtitle: _profile?.name ?? '—',
                            ),
                            _Tile(
                              icon: Icons.email_outlined,
                              title: 'Email',
                              subtitle: _profile?.email ?? '—',
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: _profile?.email ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Email copied to clipboard')),
                                );
                              },
                            ),
                            _Tile(
                              icon: _profile?.isPremium == true
                                  ? Icons.workspace_premium_rounded
                                  : Icons.stars_outlined,
                              title: 'Plan',
                              subtitle: _profile?.isPremium == true
                                  ? 'Premium'
                                  : 'Free (Tap to upgrade)',
                              iconColor: _profile?.isPremium == true
                                  ? AppColors.sun
                                  : AppColors.brand,
                              onTap: _profile?.isPremium == true
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const PremiumScreen()),
                                      ),
                            ),
                          ]),

                          _buildSection('Privacy', [
                            _SwitchTile(
                              icon: Icons.model_training_rounded,
                              title: 'Improve CommuniQ with my sessions',
                              subtitle:
                                  'Lets your anonymised session data help train '
                                  'future models. You can turn this off anytime '
                                  'without losing access to any feature.',
                              value: _trainingOptedIn,
                              updating: _trainingConsentUpdating,
                              onChanged: _updateTrainingConsent,
                            ),
                          ]),

                          _buildSection('Legal', [
                            _Tile(
                              icon: Icons.description_outlined,
                              title: 'Terms & Conditions',
                              onTap: () => _showInfoDialog(
                                  'Terms & Conditions', _kTerms),
                            ),
                            _Tile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              onTap: () =>
                                  _showInfoDialog('Privacy Policy', _kPrivacy),
                            ),
                          ]),

                          _buildSection('App', [
                            const _Tile(
                              icon: Icons.info_outline_rounded,
                              title: 'App Version',
                              subtitle: '1.0.0 (build 1)',
                            ),
                            _Tile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help & Support',
                              onTap: () => _showInfoDialog('Help & Support',
                                  'For support, reach us at support@communiq.app'),
                            ),
                          ]),

                          const SizedBox(height: AppSpacing.s8),
                          ChunkyButton(
                            label: 'Log Out',
                            icon: Icons.logout_rounded,
                            variant: ChunkyButtonVariant.danger,
                            onPressed: _handleLogout,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, padding: const EdgeInsets.only(bottom: AppSpacing.s10)),
          ChunkyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    const Divider(height: 1, color: AppColors.outline, indent: 62),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared row widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(size: 40, icon: icon, color: iconColor),
      title: Text(title, style: AppTextStyles.titleSmall),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.bodySmall)
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded,
              color: AppColors.inkSoft, size: 20)
          : null,
      onTap: onTap,
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: 4),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.updating,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(size: 40, icon: icon),
      title: Text(title, style: AppTextStyles.titleSmall),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
      isThreeLine: true,
      trailing: updating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            )
          : Switch(
              value: value,
              activeColor: AppColors.brand,
              onChanged: onChanged,
            ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: 6),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeroHeader extends StatelessWidget {
  final UserProfile? profile;
  const _ProfileHeroHeader({this.profile});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final name = profile?.name ?? user?.displayName ?? 'User';
    final email = profile?.email ?? user?.email ?? '';
    final photo = profile?.photoURL ?? user?.photoURL;
    final isPremium = profile?.isPremium ?? false;
    final level = profile?.level ?? 1;
    final levelLabel = profile?.levelLabel ?? 'Starter';

    return ChunkyCard(
      accent: isPremium ? AppColors.sun : AppColors.brand,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPremium ? AppColors.sun : AppColors.brand,
                ),
                clipBehavior: Clip.antiAlias,
                child: photo != null
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _InitialAvatar(name: name),
                      )
                    : _InitialAvatar(name: name),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: AppRadius.pillRadius,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text(
                    'Lv $level',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.inkOnDark,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CountBadge(label: levelLabel, icon: Icons.military_tech_rounded),
                    if (isPremium)
                      const CountBadge(
                        label: 'Premium',
                        color: AppColors.sun,
                        icon: Icons.workspace_premium_rounded,
                      )
                    else
                      const CountBadge(
                        label: 'Free Plan',
                        color: AppColors.inkSoft,
                        icon: Icons.stars_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: AppTextStyles.displaySmall.copyWith(color: AppColors.inkOnDark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      fill: AppColors.brand,
      borderColor: AppColors.brandDark,
      child: Row(
        children: [
          const IconTile(
            icon: Icons.workspace_premium_rounded,
            color: AppColors.inkOnDark,
            tinted: false,
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.inkOnDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlock all 150 sessions & advanced AI',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.inkOnDark.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.inkOnDark.withValues(alpha: 0.85)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING PREFERENCES SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingSection extends StatelessWidget {
  final OnboardingData onboarding;
  const _OnboardingSection({required this.onboarding});

  @override
  Widget build(BuildContext context) {
    final o = onboarding;
    final tiles = <Widget>[
      if (o.contexts.isNotEmpty)
        _chipTile(Icons.place_outlined, 'Communication Contexts', o.contexts),
      if (o.challenges.isNotEmpty)
        _chipTile(Icons.psychology_outlined, 'Challenges', o.challenges),
      if (o.speakingStyle != null)
        _infoTile(Icons.record_voice_over_outlined, 'Speaking Style',
            o.speakingStyle!),
      if (o.level != null)
        _infoTile(Icons.signal_cellular_alt_rounded, 'Skill Level', o.level!),
      if (o.primaryGoal != null)
        _infoTile(Icons.flag_outlined, 'Primary Goal', o.primaryGoal!),
      if (o.speakingNote != null && o.speakingNote!.isNotEmpty)
        _infoTile(Icons.notes_rounded, 'Personal Note', o.speakingNote!),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Onboarding preferences',
          padding: EdgeInsets.only(bottom: AppSpacing.s10),
        ),
        ChunkyCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  const Divider(height: 1, color: AppColors.outline, indent: 62),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String title, String value) => _Tile(
        icon: icon,
        title: title,
        subtitle: value,
      );

  Widget _chipTile(IconData icon, String title, List<String> items) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(size: 40, icon: icon),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  const SizedBox(height: AppSpacing.s6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: AppRadius.pillRadius,
                              ),
                              child: Text(
                                t,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.brand,
                                  letterSpacing: 0,
                                ),
                              ),
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
