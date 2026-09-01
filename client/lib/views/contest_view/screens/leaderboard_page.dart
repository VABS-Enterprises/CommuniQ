import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/leaderboard_service.dart';
import 'package:communiq/views/contest_view/widgets/leaderboard_item.dart';

/// Real, server-authoritative XP leaderboard (GET /leaderboard,
/// GET /leaderboard/weekly) — replaces the previous static kLeaderboard mock.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _weekly = false;
  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = _weekly
          ? await LeaderboardService.fetchWeekly()
          : await LeaderboardService.fetchAllTime();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the leaderboard. Pull to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.currentUser?.uid;
    final top3 = _entries.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🏆 Leaderboard',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Ranked by total XP',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── All-time / Weekly toggle ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TabToggle(
                weekly: _weekly,
                onChanged: (weekly) {
                  if (weekly == _weekly) return;
                  setState(() => _weekly = weekly);
                  _load();
                },
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _entries.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                children: [
                                  if (top3.length == 3) ...[
                                    _PodiumRow(top3: top3),
                                    const SizedBox(height: 20),
                                  ],
                                  ...List.generate(_entries.length, (i) {
                                    final e = _entries[i];
                                    return LeaderboardItem(
                                      rank: i + 1,
                                      name: e.name,
                                      score: e.xp,
                                      isCurrentUser: myUid != null && myUid == e.uid,
                                      scoreLabelBuilder: (xp) => '$xp XP',
                                      scoreColorBuilder: (_) => AppColors.primaryLight,
                                    );
                                  }),
                                ],
                              ),
                            ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOGGLE — All-time / Weekly
// ─────────────────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final bool weekly;
  final ValueChanged<bool> onChanged;
  const _TabToggle({required this.weekly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _TabButton(label: 'All-Time', active: !weekly, onTap: () => onChanged(false))),
          Expanded(child: _TabButton(label: 'This Week', active: weekly, onTap: () => onChanged(true))),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.primaryLight : AppColors.textSecondary,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'No one has practised yet — complete a session to be the first on the board!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PODIUM — visual top-3 display
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumRow extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  const _PodiumRow({required this.top3});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumBlock(entry: top3[1], rank: 2, height: 80)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumBlock(entry: top3[0], rank: 1, height: 108)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumBlock(entry: top3[2], rank: 3, height: 64)),
      ],
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;

  const _PodiumBlock({required this.entry, required this.rank, required this.height});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final color = rank == 1
        ? AppColors.scoreNeedsWork
        : rank == 2
            ? const Color(0xFF9CA3AF)
            : const Color(0xFFD97706);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(entry.name,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('${entry.xp} XP',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text('#$rank',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
        ),
      ],
    );
  }
}
