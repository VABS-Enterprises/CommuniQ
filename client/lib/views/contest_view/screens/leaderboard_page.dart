import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/contest_view/contest_state.dart';
import 'package:communiq/views/contest_view/widgets/leaderboard_item.dart';

class LeaderboardPage extends StatelessWidget {
  final int userRank;

  const LeaderboardPage({super.key, required this.userRank});

  @override
  Widget build(BuildContext context) {
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
                        Text('Weekly Contest Rankings',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Podium row (top 3) ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PodiumRow(top3: kLeaderboard.take(3).toList()),
            ),

            const SizedBox(height: 20),

            // ── Full list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kLeaderboard.length,
                itemBuilder: (context, i) {
                  final item = kLeaderboard[i];
                  final name = item['name'] as String;
                  final score = item['score'] as int;
                  final isMe = name == 'You';
                  return LeaderboardItem(
                    rank: i + 1,
                    name: name,
                    score: score,
                    isCurrentUser: isMe,
                  );
                },
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
// PODIUM — visual top-3 display
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumRow extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  const _PodiumRow({required this.top3});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        Expanded(child: _PodiumBlock(item: top3[1], rank: 2, height: 80)),
        const SizedBox(width: 8),
        // 1st place (tallest)
        Expanded(child: _PodiumBlock(item: top3[0], rank: 1, height: 108)),
        const SizedBox(width: 8),
        // 3rd place
        Expanded(child: _PodiumBlock(item: top3[2], rank: 3, height: 64)),
      ],
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  final double height;

  const _PodiumBlock(
      {required this.item, required this.rank, required this.height});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String;
    final score = item['score'] as int;
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : '🥉';
    final color = rank == 1
        ? const Color(0xFFFBBF24)
        : rank == 2
            ? const Color(0xFF9CA3AF)
            : const Color(0xFFD97706);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text('$score%',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11)),
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
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ),
        ),
      ],
    );
  }
}
