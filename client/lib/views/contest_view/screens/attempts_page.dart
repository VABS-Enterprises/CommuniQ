import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/contest_view/contest_state.dart';

class AttemptsPage extends StatelessWidget {
  final List<ContestAttempt> attempts;
  const AttemptsPage({super.key, required this.attempts});

  @override
  Widget build(BuildContext context) {
    // Sort by latest (highest number first)
    final sorted = [...attempts]..sort((a, b) => b.number.compareTo(a.number));

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Attempts',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${attempts.length} attempt${attempts.length == 1 ? '' : 's'} this week',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Progress bar summary ───────────────────────────────────────
            if (attempts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProgressSummary(attempts: attempts),
              ),

            const SizedBox(height: 20),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: sorted.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _AttemptCard(attempt: sorted[i]),
                    ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎙️', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text('No attempts yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          SizedBox(height: 8),
          Text('Start the contest to record your first attempt',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  final List<ContestAttempt> attempts;
  const _ProgressSummary({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final best = attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
    final avg =
        attempts.map((a) => a.score).reduce((a, b) => a + b) ~/ attempts.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Best Score',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Text('$best%',
                    style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                const Text('Avg Score',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Text('$avg%',
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                const Text('Total',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Text('${attempts.length}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final ContestAttempt attempt;
  const _AttemptCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final color = attempt.score >= 80
        ? const Color(0xFF22C55E)
        : attempt.score >= 65
            ? AppColors.primaryLight
            : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: attempt.isBest
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: attempt.isBest
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Number circle
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: attempt.isBest
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: attempt.isBest
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Center(
              child: Text('${attempt.number}',
                  style: TextStyle(
                      color: attempt.isBest
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attempt ${attempt.number}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                // Mini progress bar
                Container(
                  height: 4,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: attempt.score / 100.0,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.primaryDark,
                          color,
                        ]),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${attempt.score}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              if (attempt.isBest)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ),
            ],
          ),
        ],
      ),
    );
  }
}
