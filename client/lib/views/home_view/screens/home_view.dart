import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/leaderboard_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/home_view/widgets/continue_card.dart';
import 'package:communiq/views/home_view/widgets/visual_analysis_card.dart';

/// The app's landing screen: who you are, what your streak and XP look like,
/// what to do next, and how you've been performing.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  UserProfile? _profile;
  bool _profileError = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsLoading = true;

  List<LeaderboardEntry> _leaderboard = [];
  bool _leaderboardLoading = true;

  StreamSubscription<UserProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Background profile refreshes update the UI silently.
    _profileSub = SessionService.instance.profileUpdates.listen((fresh) {
      if (!mounted) return;
      setState(() {
        _profile = fresh;
        _profileError = false;
      });
    });
    _loadAll();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  /// First load reads cache; pull-to-refresh forces the network.
  Future<void> _loadAll({bool forceRefresh = false}) async {
    setState(() {
      _profileError = false;
      if (_profile == null) _isLoading = true;
      _sessionsLoading = true;
      _leaderboardLoading = true;
    });
    await Future.wait([
      forceRefresh ? _forceRefreshProfile() : _loadProfile(),
      _loadSessions(),
      _loadLeaderboard(),
    ]);
  }

  Future<void> _loadLeaderboard() async {
    try {
      final entries = await LeaderboardService.fetchAllTime();
      if (!mounted) return;
      setState(() {
        _leaderboard = entries;
        _leaderboardLoading = false;
      });
    } catch (e) {
      debugPrint('[HomeView] fetchLeaderboard failed: $e');
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  Future<void> _forceRefreshProfile() async {
    try {
      final profile = await SessionService.instance.refreshProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileError = false;
      });
    } catch (e) {
      debugPrint('[HomeView] forceRefresh failed: $e');
      // Keep showing cached data if we have it; only fail loudly when empty.
      if (mounted && _profile == null) setState(() => _profileError = true);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SessionService.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
        _profileError = false;
      });
    } catch (e) {
      debugPrint('[HomeView] fetchProfile failed: $e');
      if (!mounted) return;
      setState(() {
        if (_profile == null) _profileError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSessions() async {
    try {
      final s = await SessionService.instance.fetchSessionHistory();
      if (!mounted) return;
      setState(() {
        _sessions = s;
        _sessionsLoading = false;
      });
    } catch (e) {
      debugPrint('[HomeView] fetchSessionHistory failed: $e');
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _displayName {
    final user = AuthService.currentUser;
    final first = (_profile?.name ?? user?.displayName ?? '').split(' ').first;
    return first.isNotEmpty ? first : 'there';
  }

  /// Whisperwing reacts to how the user is actually doing.
  ///
  /// Home deliberately uses only open-eyed poses. `happy` and `celebrating`
  /// squeeze the eyes shut and lift the wings across the body, which reads as
  /// a featureless blob at this size — those belong to reward moments, not to
  /// a character sitting on screen the whole time.
  MascotMood get _mood {
    final p = _profile;
    if (_profileError) return MascotMood.sad;
    if (p == null) return MascotMood.idle;
    if (p.streak >= 3) return MascotMood.proud;
    return MascotMood.idle;
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 1,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _loadAll(forceRefresh: true),
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
                _Header(
                  greeting: _greeting,
                  name: _displayName,
                  profile: _profile,
                  onAvatarTap: () => context.go(AppRoutes.profile),
                ),
                const SizedBox(height: AppSpacing.s20),

                _MascotGreeting(mood: _mood, profile: _profile),
                const SizedBox(height: AppSpacing.s20),

                const ContinueCard(),
                const SizedBox(height: AppSpacing.s16),

                const VisualAnalysisCard(),
                const SizedBox(height: AppSpacing.s16),

                if (_isLoading)
                  const _StatsSkeleton()
                else
                  _StatsRow(profile: _profile),
                const SizedBox(height: AppSpacing.s16),

                if (_profileError) ...[
                  _InlineErrorBanner(onRetry: _loadProfile),
                  const SizedBox(height: AppSpacing.s16),
                ],

                if (!_isLoading) ...[
                  _JourneyCard(profile: _profile),
                  const SizedBox(height: AppSpacing.section),
                ],

                _PractiseCta(
                  onTap: () => context.push(AppRoutes.roleplaySetup),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Real entry point to the contest flow. The card this replaces
                // hardcoded a rank and a countdown for a feature that was a
                // mock behind a "Coming Soon" gate.
                ChunkyCard(
                  onTap: () => context.push(AppRoutes.contest),
                  // Brand stripe like every other navigation card; the trophy
                  // itself stays gold because rank is an "earned" thing.
                  accent: AppColors.brand,
                  child: Row(
                    children: [
                      const IconTile(
                        icon: Icons.emoji_events_rounded,
                        color: AppColors.sun,
                        tinted: false,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Enter a contest',
                                style: AppTextStyles.titleLarge),
                            const SizedBox(height: 2),
                            Text(
                              'Debate, GD, extempore or quiz — scored and ranked',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.inkSoft),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),

                if (!_isLoading && _profile != null) ...[
                  const SectionHeader(
                    eyebrow: 'Your skills',
                    title: 'How you\'re doing',
                  ),
                  _SkillGrid(profile: _profile!),
                  const SizedBox(height: AppSpacing.section),
                ],

                SectionHeader(
                  eyebrow: 'Standings',
                  title: 'Leaderboard',
                  actionLabel: 'View all',
                  onAction: () => context.push(AppRoutes.leaderboard),
                ),
                _LeaderboardTeaser(
                  profile: _profile,
                  entries: _leaderboard,
                  loading: _leaderboardLoading,
                  onTap: () => context.push(AppRoutes.leaderboard),
                ),
                const SizedBox(height: AppSpacing.section),

                SectionHeader(
                  eyebrow: 'History',
                  title: 'Recent practice',
                  actionLabel: _sessions.length > 3 ? 'See all' : null,
                  onAction: _sessions.length > 3
                      ? () => context.go(AppRoutes.roleplay)
                      : null,
                ),
                _RecentActivity(
                  sessions: _sessions,
                  loading: _sessionsLoading,
                  onStart: () => context.push(AppRoutes.roleplaySetup),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.profile,
    required this.onAvatarTap,
  });

  final String greeting;
  final String name;
  final UserProfile? profile;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(greeting, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 2),
              Text(
                name,
                style: AppTextStyles.displaySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        if (p != null) ...[
          StatPill(
            icon: Icons.local_fire_department_rounded,
            value: '${p.streak}',
            compact: true,
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
        GestureDetector(
          onTap: onAvatarTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: p?.photoURL != null
                ? Image.network(
                    p!.photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _AvatarFallback(),
                  )
                : const _AvatarFallback(),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.person_rounded,
        color: AppColors.inkSoft,
        size: 26,
      );
}

// ── Mascot greeting ────────────────────────────────────────────────────────

class _MascotGreeting extends StatelessWidget {
  const _MascotGreeting({required this.mood, required this.profile});

  final MascotMood mood;
  final UserProfile? profile;

  /// A line about the user's real state. Deliberately not phrased as coaching
  /// insight — the previous card presented one hardcoded "AI" critique to
  /// every user, which this replaces.
  String get _line {
    final p = profile;
    if (p == null) return 'Getting things ready…';
    if (p.streak >= 3) {
      return '${p.streak} days in a row. That consistency is exactly how fluency builds.';
    }
    if (p.streak == 1) return 'You practised today. Come back tomorrow to start a streak.';
    if (p.sessionsCompleted > 0) {
      return "You've finished ${p.sessionsCompleted} "
          "${p.sessionsCompleted == 1 ? 'session' : 'sessions'}. Ready for another?";
    }
    return "Let's get your first conversation done — it only takes a few minutes.";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Mascot(mood: mood, size: 108),
        const SizedBox(width: AppSpacing.s8),
        // A flat, borderless speech bubble rather than another hard-shadowed
        // ChunkyCard — this is ambient chatter, not a piece of data, and
        // shouldn't compete visually with the cards below it.
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WHISPERWING', style: AppTextStyles.eyebrow),
                const SizedBox(height: 4),
                Text(_line, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats ──────────────────────────────────────────────────────────────────

// A single card with two columns split by a hairline divider, rather than two
// separate hard-shadowed cards side by side — one box carrying two numbers
// instead of two boxes, which is most of what "too many boxes" meant here.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return ChunkyCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatColumn(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.sun,
                label: 'Day streak',
                value: p == null ? '—' : '${p.streak}',
                caption: p == null
                    ? ''
                    : p.streak == 0
                        ? 'Start today'
                        : 'Keep it up!',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.s14),
              child: VerticalDivider(width: 1, color: AppColors.outline),
            ),
            Expanded(
              child: _StatColumn(
                icon: Icons.bolt_rounded,
                color: AppColors.sun,
                label: 'Total XP',
                value: p == null ? '—' : '${p.xp}',
                caption: p == null ? '' : 'Lv ${p.level} · ${p.levelLabel}',
                progress: p?.xpProgress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconTile(icon: icon, color: color, size: 32),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(label, style: AppTextStyles.labelSmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Text(value, style: AppTextStyles.numeral.copyWith(fontSize: 26)),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption,
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.s10),
          ChunkyProgressBar(value: progress!, color: color, height: 10),
        ],
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  static const _column = Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonBox(width: 90, height: 14),
        SizedBox(height: AppSpacing.s12),
        SkeletonBox(width: 56, height: 26),
        SizedBox(height: AppSpacing.s8),
        SkeletonBox(height: 12),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _column,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.s14),
              child: VerticalDivider(width: 1, color: AppColors.outline),
            ),
            _column,
          ],
        ),
      ),
    );
  }
}

// ── Journey ────────────────────────────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.profile});

  final UserProfile? profile;

  /// The full curriculum length the journey is measured against.
  static const _totalSessions = 150;

  @override
  Widget build(BuildContext context) {
    final done = profile?.sessionsCompleted ?? 0;
    final pct = (done / _totalSessions).clamp(0.0, 1.0);

    return ChunkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Learning journey',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text('$done of $_totalSessions sessions',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              CountBadge(
                label: '${(pct * 100).round()}%',
                color: pct > 0 ? AppColors.brand : AppColors.inkSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
          ChunkyProgressBar(value: pct, color: AppColors.brand),
          const SizedBox(height: AppSpacing.s8),
          Text(
            done == 0
                ? 'Start your first session!'
                : 'Next milestone at ${_nextMilestone(done)} sessions',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  int _nextMilestone(int done) {
    const milestones = [10, 25, 50, 100, _totalSessions];
    return milestones.firstWhere((m) => m > done, orElse: () => _totalSessions);
  }
}

// ── Practise CTA ───────────────────────────────────────────────────────────

class _PractiseCta extends StatelessWidget {
  const _PractiseCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      fill: AppColors.brandSoft,
      borderColor: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.mic_rounded,
                color: AppColors.brand,
                tinted: false,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Practise a conversation',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Interviews, group discussions, sales calls',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
          ChunkyButton(
            label: 'Start speaking',
            icon: Icons.play_arrow_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

// ── Skills ─────────────────────────────────────────────────────────────────

class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.profile});

  final UserProfile profile;

  /// Height of one skill cell: icon row + numeral + progress bar.
  static const _cellHeight = 118.0;

  /// The six skills the evaluator scores, with a fixed display order and
  /// colour so a skill looks the same wherever it appears.
  static const _skills = <String, (String, IconData, Color)>{
    'clarity': ('Clarity', Icons.lightbulb_rounded, AppColors.sun),
    'fluency': ('Fluency', Icons.waves_rounded, AppColors.brand),
    'confidence': ('Confidence', Icons.bolt_rounded, AppColors.brand),
    'vocabulary': ('Vocabulary', Icons.menu_book_rounded, AppColors.brand),
    'grammar': ('Grammar', Icons.spellcheck_rounded, AppColors.brand),
    'pronunciation': ('Pronunciation', Icons.record_voice_over_rounded,
        AppColors.success),
  };

  @override
  Widget build(BuildContext context) {
    if (profile.skillProgress.isEmpty) {
      return ChunkyCard(
        child: Row(
          children: [
            const Mascot(mood: MascotMood.thinking, size: 62, animate: false),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                'Finish a practice session and your six skill scores will '
                'appear here.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    // Explicit rows rather than a shrink-wrapped GridView: the grid reserved
    // a trailing row's worth of height inside the outer ListView, leaving a
    // large gap before the next section.
    final cells = [
      for (final entry in _skills.entries)
        _SkillCell(
          label: entry.value.$1,
          icon: entry.value.$2,
          color: entry.value.$3,
          stat: profile.skillProgress[entry.key],
        ),
    ];

    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < cells.length ? AppSpacing.s12 : 0,
            ),
            // A fixed height rather than IntrinsicHeight: the cell's Column
            // uses spaceBetween (so it wants max height), which made
            // IntrinsicHeight resolve to a huge row.
            child: SizedBox(
              height: _cellHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cells[i]),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: i + 1 < cells.length
                        ? cells[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SkillCell extends StatelessWidget {
  const _SkillCell({
    required this.label,
    required this.icon,
    required this.color,
    required this.stat,
  });

  final String label;
  final IconData icon;
  final Color color;
  final SkillStat? stat;

  @override
  Widget build(BuildContext context) {
    final score = stat?.avg;
    final hasData = score != null && (stat?.sessions ?? 0) > 0;

    return ChunkyCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: hasData ? color : AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            hasData ? '${score.round()}' : '—',
            style: AppTextStyles.numeral.copyWith(
              fontSize: 26,
              color: hasData ? AppColors.forScore(score) : AppColors.inkSoft,
            ),
          ),
          ChunkyProgressBar(
            value: hasData ? score / 100 : 0,
            color: hasData ? AppColors.forScore(score) : AppColors.inkSoft,
            height: 8,
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard teaser ─────────────────────────────────────────────────────

class _LeaderboardTeaser extends StatelessWidget {
  const _LeaderboardTeaser({
    required this.profile,
    required this.entries,
    required this.loading,
    required this.onTap,
  });

  final UserProfile? profile;
  final List<LeaderboardEntry> entries;
  final bool loading;
  final VoidCallback onTap;

  static const _medalColors = {
    1: AppColors.sun,
    2: AppColors.inkSoft,
    3: Color(0xFFC98A4B), // bronze — not a semantic app colour, medal-only
  };

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ChunkyCard(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < 2 ? AppSpacing.s12 : 0),
              child: const Row(
                children: [
                  SkeletonBox(width: 32, height: 32, radius: BorderRadius.all(Radius.circular(16))),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(child: SkeletonBox(height: 14)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Fetch failed, or genuinely nobody has XP yet — fall back to a simple
    // "go compare" card rather than showing an empty list.
    if (entries.isEmpty) {
      final p = profile;
      return ChunkyCard(
        onTap: onTap,
        child: Row(
          children: [
            const IconTile(
              icon: Icons.emoji_events_rounded,
              color: AppColors.sun,
              tinted: false,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Where you rank', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    p == null
                        ? 'See how you compare'
                        : '${p.xp} XP · Lv ${p.level} ${p.levelLabel}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
      );
    }

    final top3 = entries.take(3).toList();
    final myUid = profile?.uid;
    final myIndex =
        myUid == null ? -1 : entries.indexWhere((e) => e.uid == myUid);
    final iAmInTop3 = myIndex >= 0 && myIndex < 3;

    return ChunkyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < top3.length; i++) ...[
            _LeaderboardRow(
              rank: i + 1,
              name: top3[i].name,
              xp: top3[i].xp,
              medalColor: _medalColors[i + 1],
              highlighted: i == myIndex,
            ),
            if (i < top3.length - 1) const SizedBox(height: AppSpacing.s10),
          ],
          if (!iAmInTop3 && myIndex >= 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s10),
              child: Divider(height: 1, color: AppColors.outline),
            ),
            _LeaderboardRow(
              rank: myIndex + 1,
              name: 'You',
              xp: entries[myIndex].xp,
              highlighted: true,
            ),
          ] else if (!iAmInTop3 && myIndex < 0 && profile != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s10),
              child: Divider(height: 1, color: AppColors.outline),
            ),
            Text(
              "You're not ranked yet — finish a session to appear here.",
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.xp,
    this.medalColor,
    this.highlighted = false,
  });

  final int rank;
  final String name;
  final int xp;
  final Color? medalColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: highlighted
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10, vertical: AppSpacing.s8)
          : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: AppRadius.chipRadius,
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medalColor ?? AppColors.transparent,
              shape: BoxShape.circle,
              border: medalColor == null
                  ? Border.all(color: AppColors.outline, width: 2)
                  : null,
            ),
            child: Text(
              '$rank',
              style: AppTextStyles.labelSmall.copyWith(
                color: medalColor != null
                    ? AppColors.inkOnDark
                    : AppColors.inkSoft,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: highlighted ? AppColors.ink : AppColors.inkMuted,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$xp XP', style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

// ── Recent activity ────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.sessions,
    required this.loading,
    required this.onStart,
  });

  final List<Map<String, dynamic>> sessions;
  final bool loading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      // One card holding three skeleton rows, not three skeleton cards.
      return ChunkyCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              const Padding(
                padding: EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40),
                    SizedBox(width: AppSpacing.s12),
                    Expanded(child: SkeletonBox(height: 16)),
                  ],
                ),
              ),
              if (i < 2)
                const Divider(height: 1, color: AppColors.outline, indent: 66),
            ],
          ],
        ),
      );
    }

    if (sessions.isEmpty) {
      return ChunkyCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          title: 'No sessions yet',
          message: 'Your practice history will appear here.',
          actionLabel: 'Start practising',
          mood: MascotMood.encouraging,
          onAction: onStart,
        ),
      );
    }

    // One card, each session a row inside it separated by a hairline — three
    // fewer hard-shadowed boxes stacked on the page than before.
    final recent = sessions.take(3).toList();
    return ChunkyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            FadeInUp(
              delay: AppMotion.staggerFor(i),
              child: _SessionRow(session: recent[i]),
            ),
            if (i < recent.length - 1)
              const Divider(height: 1, color: AppColors.outline, indent: 66),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final Map<String, dynamic> session;

  /// Session documents come straight from Firestore, so every field is
  /// treated as possibly missing or the wrong type.
  String get _title {
    final t = session['scenarioTitle'] ?? session['scenarioId'];
    return t is String && t.isNotEmpty ? t : 'Practice session';
  }

  int? get _score {
    final raw = session['overallScore'] ?? session['score'];
    if (raw is num) return raw.round();
    return null;
  }

  String get _when {
    final raw = session['createdAt'] ?? session['endedAt'];
    DateTime? dt;
    if (raw is String) dt = DateTime.tryParse(raw);
    if (raw is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(
        // Firestore may hand back seconds rather than milliseconds.
        raw > 100000000000 ? raw : raw * 1000,
      );
    }
    if (dt == null) return '';

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final tint = score != null ? AppColors.forScore(score) : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(
        children: [
          IconTile(icon: Icons.mic_rounded, color: tint, size: 40),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_when, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                '$score',
                style: AppTextStyles.numeralSmall.copyWith(
                  color: AppColors.inkOnDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline error ───────────────────────────────────────────────────────────

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      fill: AppColors.errorSoft,
      borderColor: AppColors.error,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              "Showing saved data — we couldn't refresh.",
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
            ),
          ),
          ChunkyButton(
            label: 'Retry',
            variant: ChunkyButtonVariant.secondary,
            size: ChunkyButtonSize.sm,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
