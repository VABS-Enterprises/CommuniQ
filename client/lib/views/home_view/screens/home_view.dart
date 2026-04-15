import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/home_view/widgets/ai_insight_card.dart';
import 'package:communiq/views/home_view/widgets/contest_card.dart';
import 'package:communiq/views/home_view/widgets/continue_card.dart';
import 'package:communiq/views/home_view/widgets/progress_card.dart';
import 'package:communiq/views/home_view/widgets/quick_actions_row.dart';
import 'package:communiq/views/contest_view/screens/leaderboard_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadSessions()]);
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() { _profileError = false; _isLoading = true; });
    try {
      final profile = await SessionService.instance.fetchProfile();
      if (mounted) setState(() { _profile = profile; _isLoading = false; });
    } catch (e) {
      debugPrint('[HomeView] fetchProfile failed: $e');
      if (mounted) setState(() { _profileError = true; _isLoading = false; });
    }
  }

  Future<void> _loadSessions() async {
    if (mounted) setState(() => _sessionsLoading = true);
    try {
      final s = await SessionService.instance.fetchSessionHistory();
      if (mounted) setState(() { _sessions = s; _sessionsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── 1. Header ──────────────────────────────────────────
                  _HeaderSection(
                    greeting: '${_greeting()}, $_displayName',
                    profile: _profile,
                  ),

                  const SizedBox(height: 28),

                  // ── 2. Avatar ──────────────────────────────────────────
                  _AvatarSection(photoURL: _profile?.photoURL),

                  const SizedBox(height: 28),

                  // ── 3. Continue Learning Card ─────────────────────────
                  const ContinueCard(progress: 0.45),

                  const SizedBox(height: 16),

                  // ── 4. Progress Card ───────────────────────────────────
                  _isLoading
                      ? _skeletonCard(130)
                      : ProgressCard(profile: _profile),

                  if (_profileError) ...[
                    const SizedBox(height: 10),
                    _ProfileErrorBanner(onRetry: _loadProfile),
                  ],

                  const SizedBox(height: 16),

                  // ── 5. Contest Card ────────────────────────────────────
                  const ContestCard(),

                  const SizedBox(height: 16),

                  // ── 6. This Week Improvement ───────────────────────────
                  const _ThisWeekCard(),

                  const SizedBox(height: 16),

                  // ── 7. AI Coach Suggestion ─────────────────────────────
                  const AIInsightCard(),

                  const SizedBox(height: 24),

                  // ── 8. Recent Activity ─────────────────────────────────
                  _RecentActivityWidget(
                    sessions: _sessions,
                    loading: _sessionsLoading,
                  ),

                  // Nav bar bottom clearance
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSection extends StatefulWidget {
  final String greeting;
  final UserProfile? profile;
  const _HeaderSection({required this.greeting, this.profile});

  @override
  State<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<_HeaderSection> {
  bool _leaderboardActive = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Greeting text ──────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.greeting,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Unlock your communication potential',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // ── Leaderboard icon ───────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            setState(() => _leaderboardActive = !_leaderboardActive);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LeaderboardPage(userRank: 24),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              boxShadow: _leaderboardActive
                  ? AppGlow.cyanGlow(blurRadius: 14, spreadRadius: 2)
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.leaderboard_rounded,
                size: 20,
                color: _leaderboardActive
                    ? AppColors.primary
                    : AppColors.primaryLight,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // ── Profile avatar ─────────────────────────────────────────────────
        GestureDetector(
          onTap: () => SwitchToProfileTabNotification().dispatch(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: AppGlow.cyanGlow(blurRadius: 12, spreadRadius: 1),
            ),
            child: ClipOval(
              child: widget.profile?.photoURL != null
                  ? Image.network(
                      widget.profile!.photoURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 22,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatefulWidget {
  final String? photoURL;
  const _AvatarSection({this.photoURL});

  @override
  State<_AvatarSection> createState() => _AvatarSectionState();
}

class _AvatarSectionState extends State<_AvatarSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.photoURL != null
                    ? Image.network(
                        widget.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You're improving consistently 🚀",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Image.asset(
      'assets/images/hummingbird.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.person,
        size: 60,
        color: AppColors.primaryLight,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THIS WEEK IMPROVEMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 This Week',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Confidence chip — primary purple gradient
              Expanded(
                child: _ImprovementChip(
                  label: 'Confidence',
                  delta: '+12%',
                  baseColor: AppColors.primary,       // #7C5CFF
                  accentColor: AppColors.primaryDark,  // #5A3FD9
                  textColor: AppColors.primaryLight,   // #A78BFA
                ),
              ),
              const SizedBox(width: 12),
              // Fluency chip — lighter purple
              Expanded(
                child: _ImprovementChip(
                  label: 'Fluency',
                  delta: '+8%',
                  baseColor: AppColors.primaryLight,       // #A78BFA
                  accentColor: AppColors.primary,           // #7C5CFF
                  textColor: AppColors.primaryExtraLight,   // #C4B5FD
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImprovementChip extends StatelessWidget {
  final String label;
  final String delta;
  final Color baseColor;
  final Color accentColor;
  final Color textColor;

  const _ImprovementChip({
    required this.label,
    required this.delta,
    required this.baseColor,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: textColor, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delta,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
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
// RECENT ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivityWidget extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;

  const _RecentActivityWidget({
    required this.sessions,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sessions.isNotEmpty)
              const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          )
        else if (sessions.isEmpty)
          _buildEmpty(context)
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length.clamp(0, 5),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ActivityCard(session: sessions[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.mic_none_rounded, color: AppColors.textMuted, size: 32),
          SizedBox(height: 8),
          Text(
            'No sessions yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Start your first roleplay',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _ActivityCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final title = session['scenarioTitle'] as String? ?? 'Session';
    final score = session['overallScore'];
    final scoreStr = score != null ? '$score%' : '—';

    Color scoreColor = AppColors.primary;
    if (score != null) {
      if (score >= 80) {
        scoreColor = const Color(0xFF22C55E);
      } else if (score >= 60) {
        scoreColor = Colors.orange;
      } else {
        scoreColor = Colors.redAccent;
      }
    }

    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            scoreStr,
            style: TextStyle(
              color: scoreColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
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
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load profile. Pull down to retry.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
