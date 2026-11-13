import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:communiq/core/services/offline_cache_service.dart';
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
import 'package:communiq/core/constants/app_config.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/models/user_profile.dart';

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
  String _appVersion = '';
  bool _deleting = false;

  StreamSubscription<UserProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Update silently when background refresh completes.
    _profileSub = SessionService.instance.profileUpdates.listen((fresh) {
      if (mounted)
        setState(() {
          _profile = fresh;
          _error = false;
        });
    });
    _load();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(
            () => _appVersion = '${info.version} (build ${info.buildNumber})');
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh) OfflineCacheService.invalidateFresh();
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
        final res = await ApiService.instance.dio
            .get(ApiConstants.userEvaluationProfile);
        final consent = (res.data as Map<String, dynamic>?)?['trainingConsent']
            as Map<String, dynamic>?;
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
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
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
          const SnackBar(
              content: Text('Could not update your preference. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _trainingConsentUpdating = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _profile?.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Text('Display name', style: AppTextStyles.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Save',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.brand)),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = newName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _profile?.name || !mounted) return;
    try {
      final updated = await SessionService.instance.updateName(trimmed);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          title: Text('Delete account?', style: AppTextStyles.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes your account and everything in it — '
                'sessions, reports, XP, contest results and lesson progress. '
                'It cannot be undone.\n\nType DELETE to confirm.',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'DELETE'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.inkMuted)),
            ),
            TextButton(
              onPressed: controller.text.trim().toUpperCase() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text('Delete',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      // On success AuthService signs out and the router returns to welcome.
      await AuthService.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Opens the public policy page when one is configured (AppConfig), and
  /// falls back to the copy bundled in the app.
  Future<void> _openLegal(String title, String url, String fallbackBody) async {
    if (url.isNotEmpty) {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    if (mounted) _showInfoDialog(title, fallbackBody);
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: {'subject': 'CommuniQ support'},
    );
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok && mounted) {
      _showInfoDialog(
          'Help & Support', 'Write to us at ${AppConfig.supportEmail}');
    }
  }

  void _showVisualReports() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _VisualReportsSheet(),
    );
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Text(title, style: AppTextStyles.titleLarge),
        content: SingleChildScrollView(
          child:
              Text(body, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.brand)),
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
                          if (_onboarding != null) ...[
                            _OnboardingSection(
                              onboarding: _onboarding!,
                              selfAssessedLevel: _profile?.selfAssessedLevel,
                            ),
                            const SizedBox(height: AppSpacing.section),
                          ],
                          _buildSection('Account', [
                            _Tile(
                              icon: Icons.person_outline_rounded,
                              title: 'Display Name',
                              subtitle: _profile?.name ?? '—',
                              onTap: _editName,
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
                                      content:
                                          Text('Email copied to clipboard')),
                                );
                              },
                            ),
                            _Tile(
                              icon: Icons.videocam_outlined,
                              title: 'Camera Reports',
                              subtitle:
                                  'Eye contact and posture from past sessions',
                              onTap: _showVisualReports,
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
                              onTap: () => _openLegal('Terms & Conditions',
                                  AppConfig.termsUrl, _kTerms),
                            ),
                            _Tile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              onTap: () => _openLegal('Privacy Policy',
                                  AppConfig.privacyPolicyUrl, _kPrivacy),
                            ),
                          ]),
                          _buildSection('App', [
                            _Tile(
                              icon: Icons.info_outline_rounded,
                              title: 'App Version',
                              subtitle: _appVersion.isEmpty ? '—' : _appVersion,
                            ),
                            _Tile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help & Support',
                              subtitle: AppConfig.supportEmail,
                              onTap: _contactSupport,
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.s8),
                          ChunkyButton(
                            label: 'Log Out',
                            icon: Icons.logout_rounded,
                            variant: ChunkyButtonVariant.danger,
                            onPressed: _deleting ? null : _handleLogout,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Center(
                            child: _deleting
                                ? const Padding(
                                    padding: EdgeInsets.all(AppSpacing.s12),
                                    child: CircularProgressIndicator(
                                        color: AppColors.error),
                                  )
                                : TextButton(
                                    onPressed: _confirmDeleteAccount,
                                    child: Text(
                                      'Delete account',
                                      style: AppTextStyles.labelMedium
                                          .copyWith(color: AppColors.error),
                                    ),
                                  ),
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
          SectionHeader(
              title: title,
              padding: const EdgeInsets.only(bottom: AppSpacing.s10)),
          ChunkyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    const Divider(
                        height: 1, color: AppColors.outline, indent: 62),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(size: 40, icon: icon),
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
      subtitle:
          Text(subtitle, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
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
    final level = profile?.level ?? 1;
    final levelLabel = profile?.levelLabel ?? 'Starter';

    return ChunkyCard(
      accent: AppColors.brand,
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
                  color: AppColors.brand,
                ),
                clipBehavior: Clip.antiAlias,
                child: photo != null
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _InitialAvatar(name: name),
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
                    CountBadge(
                        label: levelLabel, icon: Icons.military_tech_rounded),
                    CountBadge(
                      label: '${profile?.xp ?? 0} XP',
                      color: AppColors.sun,
                      icon: Icons.bolt_rounded,
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
// ONBOARDING PREFERENCES SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingSection extends StatelessWidget {
  final OnboardingData onboarding;
  final String? selfAssessedLevel;
  const _OnboardingSection({required this.onboarding, this.selfAssessedLevel});

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
      if ((o.level ?? selfAssessedLevel) != null)
        _infoTile(Icons.signal_cellular_alt_rounded, 'Self-assessed level',
            (o.level ?? selfAssessedLevel)!),
      if (o.primaryGoal != null)
        _infoTile(Icons.flag_outlined, 'Primary Goal', o.primaryGoal!),
      if (o.commitmentDays != null)
        _infoTile(Icons.event_repeat_rounded, 'Practice goal',
            '${o.commitmentDays} days a week'),
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
                  const Divider(
                      height: 1, color: AppColors.outline, indent: 62),
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

// ── Camera reports ────────────────────────────────────────────────────────

class _VisualReportsSheet extends StatefulWidget {
  const _VisualReportsSheet();

  @override
  State<_VisualReportsSheet> createState() => _VisualReportsSheetState();
}

class _VisualReportsSheetState extends State<_VisualReportsSheet> {
  late Future<List<Map<String, dynamic>>> _future =
      SessionService.instance.fetchVisualReports();

  static int _pct(Object? v) => v is num ? v.round() : 0;

  static String _date(Object? v) {
    final dt = v is String ? DateTime.tryParse(v)?.toLocal() : null;
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Text('Camera reports', style: AppTextStyles.titleLarge),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingStateView();
                  }
                  if (snap.hasError) {
                    return ErrorStateView(
                      title: 'Could not load reports',
                      message:
                          snap.error.toString().replaceFirst('Exception: ', ''),
                      onRetry: () => setState(() {
                        _future = SessionService.instance.fetchVisualReports();
                      }),
                    );
                  }
                  final reports = snap.data ?? const [];
                  if (reports.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      child: Text(
                        'Turn the camera on during a roleplay to get feedback on '
                        'your eye contact and posture. Your reports appear here.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    itemCount: reports.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.outline),
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconTile(
                          size: 40,
                          icon: Icons.videocam_rounded,
                          color: AppColors.forScore(
                              _pct(r['visualEngagementScore'])),
                        ),
                        title: Text(
                          'Engagement ${_pct(r['visualEngagementScore'])}%',
                          style: AppTextStyles.titleSmall,
                        ),
                        subtitle: Text(
                          'Eye contact ${_pct(r['eyeContactPercentage'])}% · '
                          'Posture ${_pct(r['overallPostureScore'])}%',
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: Text(_date(r['createdAt']),
                            style: AppTextStyles.bodySmall),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Static legal text ─────────────────────────────────────────────────────
// Shown when no public URL is configured in AppConfig. Keep it in step with
// the published policy — the store listings link to that one.

const String _kTerms = '''
Last updated: October 2026

1. Acceptance of Terms
By creating an account or using CommuniQ, you agree to these Terms. If you do not agree, do not use the app.

2. The Service
CommuniQ helps you practise spoken communication with AI conversation partners, lessons, contests and optional camera-based feedback. Feedback and scores are generated automatically for practice purposes and may be imperfect.

3. Your Account
You are responsible for keeping your sign-in credentials secure. You can delete your account at any time from Profile → Delete account.

4. Acceptable Use
Do not misuse the service: no attempts to disrupt, reverse-engineer or overload it, and no unlawful, abusive or harmful content in your conversations or answers.

5. Content
You keep ownership of what you say and write. You allow us to process it to provide the service, as described in the Privacy Policy.

6. No Warranty and Limitation of Liability
CommuniQ is provided "as is", without warranties of any kind. To the extent permitted by law, we are not liable for indirect or consequential damages arising from your use of the app.

7. Changes
We may update these Terms. We will update the date above when we do; continued use means you accept the updated Terms.

8. Contact
Questions about these Terms: ${AppConfig.supportEmail}
''';

const String _kPrivacy = '''
Last updated: October 2026

1. What we collect
• Account: your name, email address and, if you use Google or Apple sign-in, the profile details they share.
• Practice data: your onboarding answers, conversation transcripts, typed answers, scores, feedback, XP, streak, lesson and contest progress.
• Voice: audio you record in roleplay sessions is sent to our servers to be transcribed and answered. Recordings are processed to produce text and are not kept as audio files.
• Camera (optional): if you turn the camera on, your video is analysed on your device only. Video never leaves your phone — we store only summary scores such as eye-contact and posture percentages.

2. How we use it
To run your practice sessions, give you feedback, track your progress, show leaderboards (your display name, XP and best contest scores are visible to other users) and keep the service secure. If you leave "Improve CommuniQ with my sessions" on, anonymised session data may be used to improve our models; you can switch this off in Profile at any time.

3. Service providers
Your data is stored with Google Firebase. Speech recognition, AI replies and evaluations are processed by AI service providers acting on our behalf, who receive the transcript or audio needed for each request. We do not sell your personal information or use it for advertising.

4. Retention and deletion
We keep your data while your account exists. Profile → Delete account permanently removes your account and all associated data immediately.

5. Your rights
You can access and correct your data in the app, and delete it at any time. For any other request, contact ${AppConfig.supportEmail}.

6. Children
CommuniQ is not directed at children under 13.

7. Contact
${AppConfig.supportEmail}
''';
