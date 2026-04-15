import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/contest_view/contest_state.dart';

class ContestHistoryPage extends StatelessWidget {
  final List<ContestHistory> history;
  const ContestHistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 Contest History',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('All past competitions',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats summary row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryChip(
                      label: 'Participated',
                      value: '${history.length}',
                      icon: Icons.sports_esports_rounded,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryChip(
                      label: 'Best Rank',
                      value: '#${history.map((h) => h.rank).reduce((a, b) => a < b ? a : b)}',
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryChip(
                      label: 'Top Score',
                      value: '${history.map((h) => h.bestScore).reduce((a, b) => a > b ? a : b)}%',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _HistoryCard(item: history[i], index: i),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ContestHistory item;
  final int index;

  const _HistoryCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final scoreColor = item.bestScore >= 80
        ? const Color(0xFF22C55E)
        : item.bestScore >= 65
            ? AppColors.primaryLight
            : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Index circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _pill('Rank #${item.rank}', AppColors.primaryLight,
                        AppColors.primaryLight.withValues(alpha: 0.12)),
                    const SizedBox(width: 8),
                    _pill('Best ${item.bestScore}%', scoreColor,
                        scoreColor.withValues(alpha: 0.1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
