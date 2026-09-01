import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/contest_service.dart';
import 'package:communiq/models/contest_models.dart';
import 'package:communiq/views/contest_view/contest_prompts.dart';

/// Contest home: pick a format, see your recent attempts.
///
/// Replaces the previous contest_page/contest_entry_page pair, which were
/// gated behind a "Coming Soon" dialog because their scores, rank and
/// leaderboard were fabricated in memory. Everything here is server data.
class ContestHubPage extends StatefulWidget {
  const ContestHubPage({super.key});

  @override
  State<ContestHubPage> createState() => _ContestHubPageState();
}

class _ContestHubPageState extends State<ContestHubPage> {
  List<ContestAttempt> _attempts = [];
  bool _loading = true;
  String? _error;

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
      final attempts = await ContestService.instance.history(limit: 5);
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double? get _best => _attempts.isEmpty
      ? null
      : _attempts.map((a) => a.overallScore).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 7,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: const Text('Contests'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Leaderboard',
              icon: const Icon(Icons.emoji_events_rounded),
              onPressed: () => context.push(AppRoutes.contestLeaderboard),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brand,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s48,
            ),
            children: [
              _Intro(best: _best, attempts: _attempts.length),
              const SizedBox(height: AppSpacing.section),

              const SectionHeader(
                eyebrow: 'Formats',
                title: 'Pick your event',
              ),
              for (var i = 0; i < ContestType.values.length; i++)
                FadeInUp(
                  delay: AppMotion.staggerFor(i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.item),
                    child: _FormatCard(
                      type: ContestType.values[i],
                      onTap: () => context.push(
                        AppRoutes.contestPlay,
                        extra: ContestType.values[i],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s16),

              SectionHeader(
                eyebrow: 'History',
                title: 'Your attempts',
                actionLabel: _attempts.isEmpty ? null : 'See all',
                onAction: _attempts.isEmpty
                    ? null
                    : () => context.push(AppRoutes.contestHistory),
              ),
              _HistoryPreview(
                attempts: _attempts,
                loading: _loading,
                error: _error,
                onRetry: _load,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.best, required this.attempts});

  final double? best;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      accent: AppColors.brand,
      child: Row(
        children: [
          Mascot(
            mood: best != null && best! >= 70
                ? MascotMood.celebrating
                : MascotMood.encouraging,
            size: 82,
            color: AppColors.brand,
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  best == null ? 'Your first contest' : 'Best score',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 2),
                if (best == null)
                  Text(
                    'Answer a prompt, get scored on argumentation, evidence, '
                    'rebuttal and delivery.',
                    style: AppTextStyles.bodySmall,
                  )
                else ...[
                  Text(
                    '${best!.round()}',
                    style: AppTextStyles.numeral.copyWith(
                      color: AppColors.forScore(best!),
                    ),
                  ),
                  Text(
                    'across $attempts ${attempts == 1 ? 'attempt' : 'attempts'}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.type, required this.onTap});

  final ContestType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      accent: type.color,
      child: Row(
        children: [
          IconTile(icon: type.icon, color: type.color, tinted: false, size: 48),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.label, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(type.blurb, style: AppTextStyles.bodySmall),
                const SizedBox(height: 6),
                Text(
                  '“${promptFor(type)}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: type.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({
    required this.attempts,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<ContestAttempt> attempts;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: ChunkyCard(
              padding: const EdgeInsets.all(AppSpacing.s14),
              child: Row(
                children: const [
                  SkeletonBox(width: 40, height: 40),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(child: SkeletonBox(height: 16)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return ChunkyCard(
        fill: AppColors.errorSoft,
        borderColor: AppColors.error,
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Text(error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.ink)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (attempts.isEmpty) {
      return ChunkyCard(
        padding: EdgeInsets.zero,
        child: const EmptyState(
          title: 'No attempts yet',
          message: 'Pick a format above to get your first score.',
          mood: MascotMood.encouraging,
        ),
      );
    }

    return Column(
      children: [
        for (final a in attempts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: ContestAttemptRow(attempt: a),
          ),
      ],
    );
  }
}

/// One past attempt. Shared by the hub preview and the full history page.
class ContestAttemptRow extends StatelessWidget {
  const ContestAttemptRow({super.key, required this.attempt});

  final ContestAttempt attempt;

  String get _when {
    final dt = attempt.submittedAt;
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.forScore(attempt.overallScore);

    return ChunkyCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(
        children: [
          IconTile(icon: attempt.type.icon, color: attempt.type.color, size: 40),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(attempt.type.label, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (_when.isNotEmpty) _when,
                    if (attempt.xpAwarded > 0) '+${attempt.xpAwarded} XP',
                  ].join(' · '),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: AppRadius.pillRadius,
            ),
            child: Text(
              '${attempt.overallScore.round()}',
              style: AppTextStyles.numeralSmall
                  .copyWith(color: AppColors.inkOnDark),
            ),
          ),
        ],
      ),
    );
  }
}
