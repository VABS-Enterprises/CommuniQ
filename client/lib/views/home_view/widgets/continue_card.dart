import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';

/// "Pick up where you left off" — the next uncompleted level in the learning
/// journey, with overall progress through it.
class ContinueCard extends StatefulWidget {
  const ContinueCard({super.key});

  @override
  State<ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<ContinueCard> {
  CommuniqLevel? _level;
  int _completed = 0;
  int _total = 0;
  bool _loading = true;

  Curriculum? _curriculum;

  LearningProgressStore get _store => LearningProgressStore.instance;

  /// The journey a level belongs to, straight from the curriculum. This used
  /// to be a hardcoded table of 20 invented "Hub" names that had nothing to do
  /// with the content and drifted the moment a level was renamed.
  String _journeyTitleFor(CommuniqLevel level) =>
      _curriculum?.journeyFor(level.id)?.title ?? level.journeyTitle;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onProgressChanged);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onProgressChanged);
    super.dispose();
  }

  /// Progress is shared state now, so finishing a level in the Learn tab
  /// updates this card without it having to re-fetch anything.
  void _onProgressChanged() {
    if (mounted) setState(_recompute);
  }

  void _recompute() {
    final levels = _curriculum?.levels ?? const <CommuniqLevel>[];
    _total = levels.length;
    _completed = levels.where((l) => _store.isComplete(l.id)).length;
    _level = levels.cast<CommuniqLevel?>().firstWhere(
          (l) => l != null && !_store.isComplete(l.id),
          orElse: () => null,
        );
  }

  Future<void> _load() async {
    try {
      final curriculum = await LevelService.instance.fetchCurriculum();
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
        _recompute();
        _loading = false;
      });
      if (!_store.isLoaded) await _store.refresh();
    } catch (e) {
      debugPrint('[ContinueCard] load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ChunkyCard(
        child: Row(
          children: const [
            SkeletonBox(width: 56, height: 56),
            SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(width: 140, height: 16),
                  SizedBox(height: AppSpacing.s8),
                  SkeletonBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final level = _level;

    // Whole journey finished — celebrate rather than rendering nothing.
    if (level == null) {
      if (_total == 0) return const SizedBox.shrink();
      return ChunkyCard(
        onTap: () => context.go(AppRoutes.learning),
        fill: AppColors.successSoft,
        borderColor: AppColors.success,
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.success, size: 32),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Journey complete!', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text('All $_total levels done.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final progress = _total > 0 ? _completed / _total : 0.0;

    return ChunkyCard(
      onTap: () => context.go(AppRoutes.learning),
      accent: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _LevelThumb(emoji: level.emoji),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Continue learning',
                        style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${_journeyTitleFor(level)} · Level ${level.id}',
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      level.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.inkOnDark,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_completed of $_total levels done',
                  style: AppTextStyles.labelSmall),
              Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ChunkyProgressBar(
            value: progress,
            color: AppColors.brand,
            height: 12,
          ),
        ],
      ),
    );
  }
}

/// The level's own emoji, in a soft brand tile.
///
/// This used to render an unrelated roleplay illustration picked by
/// `(id - 1) % 12`, so level 13 showed the "cold call" artwork for no reason.
class _LevelThumb extends StatelessWidget {
  const _LevelThumb({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: AppColors.brand, width: 2),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}
