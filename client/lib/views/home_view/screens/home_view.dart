import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/home_view/widgets/ai_insight_card.dart';
import 'package:communiq/views/home_view/widgets/contest_card.dart';
import 'package:communiq/views/home_view/widgets/continue_card.dart';
import 'package:go_router/go_router.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/views/contest_view/screens/leaderboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME VIEW
// ─────────────────────────────────────────────────────────────────────────────

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

  StreamSubscription<UserProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Listen for background profile refreshes so UI updates silently.
    _profileSub = SessionService.instance.profileUpdates.listen((fresh) {
      if (mounted) {
        setState(() {
          _profile = fresh;
          _profileError = false;
        });
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  /// Called on first load (uses cache) and by pull-to-refresh (forces network).
  Future<void> _loadAll({bool forceRefresh = false}) async {
    setState(() {
      _profileError = false;
      if (_profile == null) _isLoading = true;
      _sessionsLoading = true;
    });
    await Future.wait([
      forceRefresh ? _forceRefreshProfile() : _loadProfile(),
      _loadSessions(),
    ]);
  }

  Future<void> _forceRefreshProfile() async {
    try {
      final profile = await SessionService.instance.refreshProfile();
      if (mounted) setState(() { _profile = profile; _profileError = false; });
    } catch (e) {
      debugPrint('[HomeView] forceRefresh failed: $e');
      if (mounted && _profile == null) setState(() => _profileError = true);
    }
  }

  Future<void> _loadProfile() async {
    try {
      // fetchProfile() returns cache instantly on subsequent calls.
      final profile = await SessionService.instance.fetchProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _profileError = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeView] fetchProfile failed: $e');
      if (mounted) {
        setState(() {
          // Only show the error banner if we have no cached data at all.
          if (_profile == null) _profileError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSessions() async {
    try {
      final s = await SessionService.instance.fetchSessionHistory();
      if (mounted) {
        setState(() {
          _sessions = s;
          _sessionsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _displayName {
    final user = AuthService.currentUser;
    final first = (_profile?.name ?? user?.displayName ?? '').split(' ').first;
    return first.isNotEmpty ? first : 'there';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SkyCampusBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadAll(forceRefresh: true),
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── 1. Header ───────────────────────────────────────────
                  _HomeHeader(
                    greeting: '${_greeting()}, $_displayName',
                    profile: _profile,
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Daily Inspiration ────────────────────────────────
                  Center(
                    child: Lottie.asset(
                      'assets/icons/Thumbs Up.json',
                      width: 216,
                      height: 216,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DailyInspirationCard(profile: _profile),

                  const SizedBox(height: 16),

                  // ── 3. Continue Learning ────────────────────────────────
                  const ContinueCard(),

                  const SizedBox(height: 16),

                  // ── 4. Streak + Daily Focus ─────────────────────────────
                  if (_isLoading)
                    _skeleton(90)
                  else
                    _StreakFocusRow(profile: _profile),

                  const SizedBox(height: 16),

                  // ── 4. Journey Progress (sessions / 150) ────────────────
                  if (_isLoading)
                    _skeleton(100)
                  else
                    _JourneyCard(profile: _profile),

                  const SizedBox(height: 16),

                  // ── 5. Skill Performance Grid ───────────────────────────
                  if (_isLoading)
                    _skeleton(220)
                  else
                    _SkillGrid(profile: _profile),

                  if (_profileError) ...[
                    const SizedBox(height: 10),
                    _ProfileErrorBanner(onRetry: _loadProfile),
                  ],

                  const SizedBox(height: 16),

                  // ── 6. Leaderboard card ─────────────────────────────────
                  _LeaderboardCard(profile: _profile),

                  const SizedBox(height: 16),

                  // ── 7. Contest CTA ──────────────────────────────────────
                  const ContestCard(),

                  const SizedBox(height: 16),

                  // ── 7. AI Coach Insight ─────────────────────────────────
                  const AIInsightCard(),

                  const SizedBox(height: 24),

                  // ── 8. Recent Activity ──────────────────────────────────
                  _RecentActivity(
                    sessions: _sessions,
                    loading: _sessionsLoading,
                  ),

                  // nav bar clearance
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _skeleton(double h) => Container(
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY INSPIRATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DailyInspirationCard extends StatefulWidget {
  final UserProfile? profile;
  const _DailyInspirationCard({this.profile});

  @override
  State<_DailyInspirationCard> createState() => _DailyInspirationCardState();
}

class _DailyInspirationCardState extends State<_DailyInspirationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // One quote per slot; rotates by day-of-year so it feels fresh every morning.
  static const _quotes = [
    (
      text: 'Every session you complete is a feather in your wing. Keep flapping — you\'re closer to soaring than you think.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'I\'ve watched many learners give up right before their breakthrough. Don\'t be one of them. Practice today.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Even in the darkest night, I find my way. Your voice is your light — trust it, use it, let it guide you.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Words are your wings. The more you practice, the higher and farther you\'ll soar. Start today.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Patience, young one. Fluency isn\'t built in a day — but every conversation you have builds it brick by brick.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Wise owls don\'t fear silence. We listen deeply, then speak with purpose. Try that in your next session.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'I\'ve seen the greatest communicators start with a single shaky sentence. Yours counts too. Keep going.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Consistency is the spell that transforms beginners into masters. Show up today — tomorrow will thank you.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'The world is full of conversations waiting for your voice. Don\'t let fear keep them waiting any longer.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
    (
      text: 'Your accent? That\'s courage made audible. You\'re speaking in someone else\'s language. That\'s remarkable.',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFF38BDF8),
    ),
  ];

  late final _QuoteDef _quote;

  @override
  void initState() {
    super.initState();
    final dayIndex = DateTime.now().dayOfYear % _quotes.length;
    _quote = _quotes[dayIndex];

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile?.name.split(' ').first ?? '';
    final streak = widget.profile?.streak ?? 0;

    final sub = streak > 0
        ? '$streak-day streak 🔥 — keep it going${name.isNotEmpty ? ", $name" : ""}!'
        : name.isNotEmpty
            ? 'Ready to grow today, $name?'
            : 'Ready to grow today?';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ────────────────────────────────────────
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),

                // ── Content ────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon container
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Text column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Label
                              const Text(
                                'WHISPERWING SAYS',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Quote
                              Text(
                                '"${_quote.text}"',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Sub-line
                              Text(
                                sub,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

typedef _QuoteDef = ({String text, IconData icon, Color accent});

extension on DateTime {
  int get dayOfYear {
    final start = DateTime(year, 1, 1);
    return difference(start).inDays;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final UserProfile? profile;
  const _HomeHeader({required this.greeting, this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Keep growing every day',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Profile avatar
        GestureDetector(
          onTap: () => context.go(AppRoutes.profile),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: ClipOval(
              child: profile?.photoURL != null
                  ? Image.network(
                      profile!.photoURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initials(),
                    )
                  : _initials(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initials() {
    final name = profile?.name ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. LEVEL / XP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _LevelXpBar extends StatelessWidget {
  final UserProfile? profile;
  const _LevelXpBar({this.profile});

  @override
  Widget build(BuildContext context) {
    final level = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;
    final progress = profile?.xpProgress ?? 0.0;
    final toNext = profile?.xpToNextLevel ?? 300;
    final label = profile?.levelLabel ?? 'Starter';
    final nextLabel = profile != null && toNext > 0
        ? UserProfile.levelLabels[(level).clamp(0, UserProfile.levelLabels.length - 1)]
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Label + rank name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      toNext > 0 && nextLabel != null
                          ? 'Next rank: $nextLabel'
                          : 'Max rank reached!',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // XP pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          Stack(
            children: [
              // Track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Fill with glow
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Bottom stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                toNext > 0 ? '$toNext XP to level up' : 'Fully levelled up!',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. STREAK + DAILY FOCUS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _StreakFocusRow extends StatelessWidget {
  final UserProfile? profile;
  const _StreakFocusRow({this.profile});

  @override
  Widget build(BuildContext context) {
    final streak = profile?.streak ?? 0;
    final xp = profile?.xp ?? 0;
    final level = profile?.level ?? 1;
    final label = profile?.levelLabel ?? 'Starter';

    return Row(
      children: [
        // Streak card
        Expanded(
          child: _MiniStatCard(
            iconWidget: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 18)),
            ),
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFEF4444),
            label: 'Day Streak',
            value: streak == 0 ? 'Start Today' : '$streak Days',
            subtitle: streak == 0
                ? 'No streak yet'
                : streak >= 7
                    ? 'Amazing! 🔥'
                    : 'Keep it up!',
          ),
        ),
        const SizedBox(width: 12),
        // XP card
        Expanded(
          child: _MiniStatCard(
            iconWidget: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 18)),
            ),
            iconColor: AppColors.primary,
            iconBg: AppColors.primary,
            label: 'Total XP',
            value: '$xp XP',
            subtitle: 'Lv $level · $label',
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String subtitle;

  const _MiniStatCard({
    this.icon,
    this.iconWidget,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: iconWidget ?? Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. JOURNEY CARD  (sessions completed / 150)
// ─────────────────────────────────────────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  final UserProfile? profile;
  const _JourneyCard({this.profile});

  @override
  Widget build(BuildContext context) {
    const int total = 150;
    final completed = profile?.sessionsCompleted ?? 0;
    final progress = (completed / total).clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    // Milestone thresholds
    final milestones = [0, 10, 25, 50, 75, 100, 150];
    final nextMilestone = milestones.firstWhere(
      (m) => m > completed,
      orElse: () => 150,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learning Journey',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completed of $total sessions',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented progress bar with milestone ticks
          SizedBox(
            height: 10,
            child: _MilestoneProgressBar(
              progress: progress,
              milestones: milestones,
              total: total,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed == 0
                    ? 'Start your first session!'
                    : nextMilestone > completed
                        ? '${nextMilestone - completed} sessions to next milestone'
                        : 'Journey complete! 🎉',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              Text(
                'Next: $nextMilestone',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneProgressBar extends StatelessWidget {
  final double progress;
  final List<int> milestones;
  final int total;

  const _MilestoneProgressBar({
    required this.progress,
    required this.milestones,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          children: [
            // Track
            Container(
              width: w,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              width: w * progress,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Milestone ticks
            for (final m in milestones.where((m) => m > 0 && m < total))
              Positioned(
                left: w * (m / total) - 1,
                top: 0,
                child: Container(
                  width: 2,
                  height: 10,
                  color: AppColors.background,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. SKILL PERFORMANCE GRID
// ─────────────────────────────────────────────────────────────────────────────

class _SkillGrid extends StatelessWidget {
  final UserProfile? profile;
  const _SkillGrid({this.profile});

  static const _skills = [
    _SkillMeta('Clarity', Icons.record_voice_over_rounded, Color(0xFF38BDF8)),
    _SkillMeta('Fluency', Icons.waves_rounded, Color(0xFF818CF8)),
    _SkillMeta('Confidence', Icons.psychology_rounded, Color(0xFF7C3AED)),
    _SkillMeta('Vocabulary', Icons.menu_book_rounded, Color(0xFF10B981)),
    _SkillMeta('Grammar', Icons.spellcheck_rounded, Color(0xFFF59E0B)),
    _SkillMeta('Pronunciation', Icons.mic_rounded, Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = profile?.skillProgress ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skill Performance',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Across all completed sessions',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (profile?.overallSkillAvg != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Avg ${profile!.overallSkillAvg!.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (sp.isEmpty) ...[
            // No data yet
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Complete sessions to unlock\nyour skill insights',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Grid of 3 × 2
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemCount: _skills.length,
              itemBuilder: (_, i) {
                final meta = _skills[i];
                final key = meta.label.toLowerCase();
                final stat = sp[key];
                final avg = stat?.avg ?? 0.0;
                final sessions = stat?.sessions ?? 0;
                return _SkillCell(
                  meta: meta,
                  avg: avg,
                  sessions: sessions,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _SkillMeta(this.label, this.icon, this.color);
}

class _SkillCell extends StatelessWidget {
  final _SkillMeta meta;
  final double avg;
  final int sessions;

  const _SkillCell({
    required this.meta,
    required this.avg,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (avg / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: meta.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: frac,
                  strokeWidth: 5,
                  backgroundColor:
                      meta.color.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(meta.color),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: sessions == 0
                      ? Icon(meta.icon,
                          size: 18,
                          color: meta.color.withValues(alpha: 0.5))
                      : Text(
                          '${avg.round()}',
                          style: TextStyle(
                            color: meta.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sessions == 0 ? 'No data' : '$sessions session${sessions == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. LEADERBOARD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardCard extends StatelessWidget {
  final UserProfile? profile;
  const _LeaderboardCard({this.profile});

  @override
  Widget build(BuildContext context) {
    const rankColor = Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Real, server-authoritative XP leaderboard (GET /leaderboard) —
        // no longer gated behind "Coming Soon" now that it's wired up.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            // Leaderboard icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.leaderboard_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile != null
                        ? 'See how you rank among all speakers'
                        : 'Compete with speakers worldwide',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Arrow
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. RECENT ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  const _RecentActivity({required this.sessions, required this.loading});

  @override
  Widget build(BuildContext context) {
    final recent = sessions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Sessions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sessions.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20)),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Body ─────────────────────────────────────────────────────────────
        if (loading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          )
        else if (recent.isEmpty)
          _emptyState()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _SessionRow(session: recent[i]),
                  if (i < recent.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.glassBorder.withValues(alpha: 0.25),
                      indent: 68,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.glassBorder.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_none_rounded,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 12),
            const Text(
              'No sessions yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start your first AI roleplay',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionRow({required this.session});

  /// Safely extracts a timestamp string from a session field.
  /// Handles three forms Firestore/Node may return:
  ///   - ISO string          "2024-01-15T12:00:00.000Z"
  ///   - Firestore Timestamp { "_seconds": 1705320000, "_nanoseconds": 0 }
  ///   - null / missing
  static String? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000,
                isUtc: true)
            .toIso8601String();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = session['scenarioTitle']?.toString() ?? 'Session';
    final score = (session['overallScore'] as num?)?.toDouble();
    final status = session['status']?.toString() ?? 'completed';
    final endedAt = _parseTimestamp(session['endedAt']);

    final isAbandoned = status == 'abandoned';

    // Score — always use primary color
    const scoreColor = AppColors.primary;
    final scoreBg = score != null
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.surfaceVariant;
    final scoreStr = score != null ? '${score.round()}' : '—';

    // Accent colour for the left bar
    final accentColor = isAbandoned
        ? AppColors.textMuted.withValues(alpha: 0.4)
        : AppColors.primary.withValues(alpha: 0.6);

    String? timeAgo;
    if (endedAt != null) {
      try {
        final dt = DateTime.parse(endedAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inMinutes}m ago';
        }
      } catch (_) {}
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left accent bar ──────────────────────────────────────────────
          Container(width: 3, color: accentColor),

          // ── Row content ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isAbandoned
                          ? AppColors.textMuted.withValues(alpha: 0.15)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isAbandoned
                          ? Icons.cancel_outlined
                          : Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isAbandoned
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isAbandoned
                                    ? AppColors.textMuted
                                        .withValues(alpha: 0.08)
                                    : AppColors.emerald
                                        .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAbandoned ? 'Abandoned' : 'Completed',
                                style: TextStyle(
                                  color: isAbandoned
                                      ? AppColors.textMuted
                                      : AppColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (timeAgo != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Score badge
                  if (!isAbandoned && score != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            scoreStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const Text(
                            'Score',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProfileErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load profile. Pull down to retry.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
