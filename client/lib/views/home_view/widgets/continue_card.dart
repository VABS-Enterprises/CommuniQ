import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
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

  /// Hub names, one per level block — mirrors the order in learning_view.
  static const _hubNames = [
    'Introduction Hub', 'Conversation Hub', 'Professional Hub',
    'Influence Hub', 'Expression Hub', 'Pro Skills Hub',
    'Dialogue Hub', 'Office Hub', 'Social Hub', 'Work–Life Hub',
    'Crisis Hub', 'High-Stakes Hub', 'Leadership Hub',
    'Power Hub', 'Legacy Hub', 'Mastery Hub',
    'Elite Hub', 'Pinnacle Hub', 'Visionary Hub', 'Apex Hub',
  ];

  String _hubFor(int levelId) =>
      _hubNames[(levelId - 1).clamp(0, _hubNames.length - 1)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doneIds = (prefs.getStringList('completed_level_ids') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      final levels = await LevelService.instance.fetchLevels();
      final journey = levels.take(20).toList();

      CommuniqLevel? current;
      for (final l in journey) {
        if (!doneIds.contains(l.id)) {
          current = l;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _level = current;
        _completed = journey.where((l) => doneIds.contains(l.id)).length;
        _total = journey.length;
        _loading = false;
      });
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
      accent: AppColors.grape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _LevelThumb(asset: level.imageAsset),
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
                      '${_hubFor(level.id)} · Level ${level.id}',
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      level.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.grape,
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
                  color: AppColors.grape,
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
                  color: AppColors.grape,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ChunkyProgressBar(
            value: progress,
            color: AppColors.grape,
            height: 12,
          ),
        ],
      ),
    );
  }
}

/// The scenario artwork is dark, high-contrast illustration that would clash
/// directly on the cream card. Framing it in its own dark tile presents it as
/// a deliberate thumbnail instead.
class _LevelThumb extends StatelessWidget {
  const _LevelThumb({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.school_rounded,
          color: AppColors.grape,
          size: 26,
        ),
      ),
    );
  }
}
