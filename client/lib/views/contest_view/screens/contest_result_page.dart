import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/confetti_overlay.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/models/contest_models.dart';

/// The scored result of a contest submission.
///
/// Every number here comes from ai-server's evaluator via
/// POST /contest/submit — nothing is computed or invented locally.
class ContestResultPage extends StatelessWidget {
  const ContestResultPage({super.key, required this.result});

  final ContestResult result;

  bool get _strong => result.overallScore >= 70;

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      play: _strong,
      child: PlayfulBackground(
        seed: 9,
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          appBar: AppBar(
            title: const Text('Your score'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => context.go(AppRoutes.contest),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s32,
            ),
            children: [
              _ScoreHero(result: result, strong: _strong),
              const SizedBox(height: AppSpacing.section),

              const SectionHeader(eyebrow: 'Breakdown', title: 'By dimension'),
              ChunkyCard(
                child: Column(
                  children: [
                    for (final entry in result.scores.asMap.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s14),
                        child: _ScoreRow(
                          label: entry.key,
                          value: entry.value,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              if (result.strengths.isNotEmpty) ...[
                const SectionHeader(
                  eyebrow: 'What worked',
                  title: 'Strengths',
                ),
                _PointList(
                  points: result.strengths,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.section),
              ],

              if (result.improvements.isNotEmpty) ...[
                const SectionHeader(
                  eyebrow: 'Next time',
                  title: 'Improvements',
                ),
                _PointList(
                  points: result.improvements,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.info,
                ),
                const SizedBox(height: AppSpacing.section),
              ],

              if (result.feedback.isNotEmpty) ...[
                const SectionHeader(eyebrow: 'Coach', title: 'Overall'),
                ChunkyCard(
                  accent: AppColors.teal,
                  child: Text(result.feedback, style: AppTextStyles.bodyLarge),
                ),
                const SizedBox(height: AppSpacing.section),
              ],

              ChunkyButton(
                label: 'Back to contests',
                icon: Icons.emoji_events_rounded,
                onPressed: () => context.go(AppRoutes.contest),
              ),
              const SizedBox(height: AppSpacing.s10),
              ChunkyButton(
                label: 'See the leaderboard',
                variant: ChunkyButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.contestLeaderboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.result, required this.strong});

  final ContestResult result;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.forScore(result.overallScore);

    return ChunkyCard(
      accent: tint,
      child: Column(
        children: [
          Mascot(
            mood: strong ? MascotMood.celebrating : MascotMood.encouraging,
            size: 110,
            color: tint,
          ),
          const SizedBox(height: AppSpacing.s8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: result.overallScore),
            duration: AppMotion.celebrate,
            curve: AppMotion.ease,
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: AppTextStyles.displayLarge.copyWith(
                fontSize: 56,
                color: tint,
              ),
            ),
          ),
          Text('out of 100', style: AppTextStyles.bodySmall),
          if (result.xpAwarded > 0) ...[
            const SizedBox(height: AppSpacing.s12),
            StatPill(
              icon: Icons.bolt_rounded,
              value: '+${result.xpAwarded} XP',
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.forScore(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.titleSmall)),
            Text(
              '${value.round()}',
              style: AppTextStyles.numeralSmall.copyWith(color: tint),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ChunkyProgressBar(value: value / 100, color: tint, height: 10),
      ],
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.points,
    required this.icon,
    required this.color,
  });

  final List<String> points;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      child: Column(
        children: [
          for (var i = 0; i < points.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == points.length - 1 ? 0 : AppSpacing.s12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(points[i], style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
