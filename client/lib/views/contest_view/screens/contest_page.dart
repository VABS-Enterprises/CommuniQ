import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/views/contest_view/contest_state.dart';
import 'package:communiq/views/contest_view/screens/contest_result_page.dart';
import 'package:communiq/views/contest_view/screens/leaderboard_page.dart';
import 'package:communiq/views/contest_view/screens/contest_history_page.dart';
import 'package:communiq/views/contest_view/screens/attempts_page.dart';
import 'package:communiq/views/contest_view/widgets/contest_main_card.dart';
import 'package:communiq/views/contest_view/widgets/performance_card.dart';
import 'package:communiq/views/contest_view/widgets/leaderboard_item.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

class ContestPage extends StatefulWidget {
  const ContestPage({super.key});

  @override
  State<ContestPage> createState() => _ContestPageState();
}

class _ContestPageState extends State<ContestPage>
    with SingleTickerProviderStateMixin {
  // ── Shared state (persists across pushes via setState after pop) ───────────
  final ContestState _state = ContestState();

  // Seed with two mock attempts so the page looks populated on first open
  // (remove these lines and set hasAttempted=false for a clean slate)
  _ContestPageState() {
    _state.hasAttempted = true;
    _state.bestScore = 78;
    _state.rank = 8;
    _state.xpEarned = 100;
    _state.attempts.addAll([
      const ContestAttempt(number: 1, score: 65, isBest: false),
      const ContestAttempt(number: 2, score: 78, isBest: true),
    ]);
  }

  final int _secondsLeft = (2 * 24 + 14) * 3600;

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  String get _countdown {
    final d = _secondsLeft ~/ 86400;
    final h = (_secondsLeft % 86400) ~/ 3600;
    return '${d}d ${h}h';
  }

  // ── Navigate to roleplay → result ─────────────────────────────────────────
  Future<void> _startContest() async {
    // Push setup screen; when the conversation finishes it pops all the way
    // back here, and we then push the result page with the simulated score.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplaySetupScreen(
          mode: 'prefilled',
          scenario: 'Job Interview',
          difficulty: 'Medium',
          category: 'Assertiveness',
        ),
      ),
    );

    // After roleplay, simulate score and go to ResultPage
    if (!mounted) return;
    final simulatedScore = 65 + (_state.attempts.length * 7).clamp(0, 30);
    final attemptNum = _state.attempts.length + 1;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContestResultPage(
          score: simulatedScore,
          attemptNumber: attemptNum,
          contestState: _state,
          onTryAgain: _startContest,
        ),
      ),
    );

    // Refresh UI after coming back from result
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Top 3 + current user row for the mini leaderboard
    final top3 = kLeaderboard.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── 1. Header ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: _ContestHeader(
                    countdown: _countdown,
                    onBack: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 2. Main Contest Card ────────────────────────────────────
                ContestMainCard(
                  hasAttempted: _state.hasAttempted,
                  onStart: _startContest,
                ),

                // ── 3. Performance (only after first attempt) ───────────────
                if (_state.hasAttempted) ...[
                  const SizedBox(height: 24),
                  PerformanceCard(
                      rank: _state.rank, bestScore: _state.bestScore),
                ],

                const SizedBox(height: 24),

                // ── 4. Mini Leaderboard ─────────────────────────────────────
                _SectionRow(
                  title: '🏆 Leaderboard',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _MiniLeaderboard(
                  top3: top3,
                  userRank: _state.rank,
                  userScore: _state.bestScore,
                ),

                const SizedBox(height: 24),

                // ── 5. Contest History ──────────────────────────────────────
                _SectionRow(
                  title: '📋 Recent Contests',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContestHistoryPage(history: _state.history),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ContestHistorySection(
                    history: _state.history.take(3).toList()),

                // ── 6. Attempts ─────────────────────────────────────────────
                if (_state.hasAttempted) ...[
                  const SizedBox(height: 24),
                  _SectionRow(
                    title: 'Your Attempts',
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AttemptsPage(attempts: _state.attempts),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AttemptsSection(
                      attempts: _state.attempts.reversed
                          .take(2)
                          .toList()
                          .reversed
                          .toList()),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ContestHeader extends StatelessWidget {
  final String countdown;
  final VoidCallback onBack;

  const _ContestHeader({required this.countdown, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🏆 Contest Arena',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Weekly Challenge  •  Climb the leaderboard 🚀',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            boxShadow: AppGlow.cyanGlow(blurRadius: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(countdown,
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION ROW  (title + see-all button)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionRow({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onSeeAll,
          child: Row(
            children: [
              Text('See All',
                  style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.primaryLight, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _MiniLeaderboard extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  final int userRank;
  final int userScore;

  const _MiniLeaderboard(
      {required this.top3,
      required this.userRank,
      required this.userScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mini Podium
          _MiniPodiumRow(top3: top3),
          
          const SizedBox(height: 24),
          
          // Current user row (glowing)
          LeaderboardItem(
            rank: userRank,
            name: 'You',
            score: userScore,
            isCurrentUser: true,
          ),
        ],
      ),
    );
  }
}

class _MiniPodiumRow extends StatelessWidget {
  final List<Map<String, dynamic>> top3;

  const _MiniPodiumRow({required this.top3});

  @override
  Widget build(BuildContext context) {
    if (top3.length < 3) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _MiniPodiumItem(rank: 2, name: top3[1]['name'], score: top3[1]['score']),
        _MiniPodiumItem(rank: 1, name: top3[0]['name'], score: top3[0]['score'], isCenter: true),
        _MiniPodiumItem(rank: 3, name: top3[2]['name'], score: top3[2]['score']),
      ],
    );
  }
}

class _MiniPodiumItem extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool isCenter;

  const _MiniPodiumItem({
    required this.rank,
    required this.name,
    required this.score,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final avatarSize = isCenter ? 60.0 : 48.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal & Avatar
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: rank == 1 
                      ? AppColors.gold 
                      : rank == 2 
                          ? const Color(0xFFC0C0C0) 
                          : const Color(0xFFCD7F32),
                  width: 2,
                ),
                boxShadow: isCenter ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ] : null,
              ),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFF1F2937),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isCenter ? 24 : 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(medal, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          name.split(' ')[0],
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: isCenter ? 14 : 12,
            fontWeight: isCenter ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$score%',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: isCenter ? 12 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEST HISTORY SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _ContestHistorySection extends StatelessWidget {
  final List<ContestHistory> history;
  const _ContestHistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(history.length, (i) {
          final item = history[i];
          final isLast = i == history.length - 1;
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                        child:
                            Text('🏆', style: TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('Rank #${item.rank}  •  Best ${item.bestScore}%',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  _scoreChip(item.bestScore),
                ],
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: AppColors.border, height: 1),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _scoreChip(int score) {
    final color = score >= 80
        ? AppColors.scoreExcellent
        : score >= 65
            ? AppColors.primaryLight
            : AppColors.scoreNeedsWork;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$score%',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTEMPTS SECTION (inline, last 2)
// ─────────────────────────────────────────────────────────────────────────────

class _AttemptsSection extends StatelessWidget {
  final List<ContestAttempt> attempts;
  const _AttemptsSection({required this.attempts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(attempts.length, (i) {
          final a = attempts[i];
          final isLast = i == attempts.length - 1;
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: a.isBest
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: a.isBest
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border),
                    ),
                    child: Center(
                        child: Text('${a.number}',
                            style: TextStyle(
                                color: a.isBest
                                    ? AppColors.primaryLight
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 14))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Attempt ${a.number}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Text('${a.score}%',
                      style: TextStyle(
                          color: a.isBest
                              ? AppColors.primaryLight
                              : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(width: 8),
                  if (a.isBest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Best',
                          style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                  else
                    const SizedBox(width: 37),
                ],
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: AppColors.border, height: 1),
                ),
            ],
          );
        }),
      ),
    );
  }
}
