import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/premium_view/screens/premium_screen.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/common_widgets/icon_tile.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(body,
              style:
                  const TextStyle(color: AppColors.textSecondary, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkyCampusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : _error
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: () => _load(forceRefresh: true),
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // ── Hero Header ─────────────────────────────────
                          SliverToBoxAdapter(child: _ProfileHeroHeader(profile: _profile)),

                          const SliverToBoxAdapter(child: SizedBox(height: 16)),

                          // ── Premium Banner (if not premium) ─────────────
                          if (_profile?.isPremium != true)
                            SliverToBoxAdapter(
                                child: _PremiumBanner(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const PremiumScreen())))),

                          // ── Onboarding Preferences ──────────────────────
                          if (_onboarding != null)
                            SliverToBoxAdapter(
                                child: _OnboardingSection(
                                    onboarding: _onboarding!)),

                          // ── Account Section ─────────────────────────────
                          SliverToBoxAdapter(
                              child: _buildSection('Account', [
                            _buildTile(
                              Icons.person_outline_rounded,
                              'Display Name',
                              subtitle: _profile?.name ?? '—',
                            ),
                            _buildTile(
                              Icons.email_outlined,
                              'Email',
                              subtitle: _profile?.email ?? '—',
                              onTap: () {
                                Clipboard.setData(ClipboardData(
                                    text: _profile?.email ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Email copied to clipboard')),
                                );
                              },
                            ),
                            _buildTile(
                              _profile?.isPremium == true
                                  ? Icons.workspace_premium_rounded
                                  : Icons.stars_outlined,
                              'Plan',
                              subtitle: _profile?.isPremium == true
                                  ? 'Premium'
                                  : 'Free (Tap to upgrade)',
                              trailingColor: _profile?.isPremium == true
                                  ? AppColors.gold
                                  : AppColors.primary,
                              onTap: _profile?.isPremium == true
                                  ? null
                                  : () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const PremiumScreen()));
                                    },
                            ),
                          ])),

                          // ── Privacy ──────────────────────────────────────
                          SliverToBoxAdapter(
                              child: _buildSection('Privacy', [
                            _buildSwitchTile(
                              Icons.model_training_rounded,
                              'Improve CommuniQ with my sessions',
                              subtitle: 'Lets your anonymised session data help train '
                                  'future models. You can turn this off anytime without '
                                  'losing access to any feature.',
                              value: _trainingOptedIn,
                              updating: _trainingConsentUpdating,
                              onChanged: _updateTrainingConsent,
                            ),
                          ])),

                          // ── Legal ───────────────────────────────────────
                          SliverToBoxAdapter(
                              child: _buildSection('Legal', [
                            _buildTile(Icons.description_outlined,
                                'Terms & Conditions',
                                onTap: () => _showInfoDialog(
                                    'Terms & Conditions', _kTerms)),
                            _buildTile(
                                Icons.privacy_tip_outlined, 'Privacy Policy',
                                onTap: () => _showInfoDialog(
                                    'Privacy Policy', _kPrivacy)),
                          ])),

                          // ── App ─────────────────────────────────────────
                          SliverToBoxAdapter(
                              child: _buildSection('App', [
                            _buildTile(Icons.info_outline_rounded, 'App Version',
                                subtitle: '1.0.0 (build 1)'),
                            _buildTile(Icons.help_outline_rounded,
                                'Help & Support',
                                onTap: () => _showInfoDialog('Help & Support',
                                    'For support, reach us at support@communiq.app')),
                          ])),

                          // ── Log Out ─────────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: AppColors.glassBorder
                                          .withValues(alpha: 0.4)),
                                ),
                                child: ListTile(
                                  leading: const IconTile(
                                    size: 34,
                                    icon: Icons.logout_rounded,
                                    color: AppColors.error,
                                  ),
                                  title: const Text('Log Out',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  onTap: _handleLogout,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                ),
                              ),
                            ),
                          ),

                          const SliverToBoxAdapter(
                              child: SizedBox(height: 80)),
                        ],
                      ),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.cloud_off_rounded,
                color: AppColors.textMuted, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load profile',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your account may not exist yet, or the server is unreachable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 18),
            label: const Text('Retry',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded,
                  color: Colors.redAccent, size: 18),
              label: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onPressed: _handleLogout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                        height: 1,
                        color: AppColors.glassBorder.withValues(alpha: 0.3),
                        indent: 50),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
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
      leading: IconTile(size: 34, icon: icon),
      title: Text(title,
          style:
              const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded,
              color: trailingColor ?? AppColors.textMuted, size: 20)
          : null,
      onTap: onTap,
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title, {
    required String subtitle,
    required bool value,
    required bool updating,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: IconTile(size: 34, icon: icon),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
      isThreeLine: true,
      trailing: updating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          : Switch(
              value: value,
              activeColor: AppColors.primary,
              onChanged: onChanged,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with level badge overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPremium
                          ? AppColors.gold
                          : AppColors.primary,
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.transparent,
                      backgroundImage:
                          photo != null ? NetworkImage(photo) : null,
                      child: photo == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  // Level badge
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.background, width: 2),
                      ),
                      child: Text(
                        'Lv $level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // Name / email / badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Level label chip
                        _Chip(
                          label: levelLabel,
                          color: AppColors.primary,
                          icon: Icons.military_tech_rounded,
                        ),
                        const SizedBox(width: 8),
                        // Premium/Free chip
                        if (isPremium)
                          _Chip(
                            label: 'Premium',
                            color: AppColors.gold,
                            icon: Icons.workspace_premium_rounded,
                            textColor: Colors.black,
                          )
                        else
                          _Chip(
                            label: 'Free Plan',
                            color: AppColors.textMuted,
                            icon: Icons.stars_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Color? textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.icon,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor ?? color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Unlock all 150 sessions & advanced AI',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white70),
            ],
          ),
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ONBOARDING PREFERENCES',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.glassBorder.withValues(alpha: 0.3),
                      indent: 50,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) => ListTile(
        leading: IconTile(size: 34, icon: icon),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13)),
        subtitle: Text(value,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      );

  Widget _chipTile(IconData icon, String title, List<String> items) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(size: 34, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 11,
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
