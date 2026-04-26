import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/home_view/widgets/quick_actions_row.dart';

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

  // Hub names matching learning_view.dart _kHubs order (one hub per level block).
  static const _hubNames = [
    'Introduction Hub', 'Conversation Hub', 'Professional Hub',
    'Influence Hub', 'Expression Hub', 'Pro Skills Hub',
    'Dialogue Hub', 'Office Hub', 'Social Hub', 'Work–Life Hub',
    'Crisis Hub', 'High-Stakes Hub', 'Leadership Hub',
    'Power Hub', 'Legacy Hub', 'Mastery Hub',
    'Elite Hub', 'Pinnacle Hub', 'Visionary Hub', 'Apex Hub',
  ];

  String _hubFor(int levelId) {
    // Levels 1-20: one hub per level. Re-uses last hub if beyond range.
    final idx = (levelId - 1).clamp(0, _hubNames.length - 1);
    return _hubNames[idx];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doneIds =
          (prefs.getStringList('completed_level_ids') ?? []).map(int.parse).toSet();
      final levels = await LevelService.instance.fetchLevels();
      final journey = levels.take(20).toList();

      CommuniqLevel? current;
      for (final l in journey) {
        if (!doneIds.contains(l.id)) {
          current = l;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _level = current;
          _completed = journey.where((l) => doneIds.contains(l.id)).length;
          _total = journey.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    // Nothing to show if all levels done
    if (_level == null) return const SizedBox.shrink();

    final progress = _total > 0 ? _completed / _total : 0.0;
    final hub = _hubFor(_level!.id);

    return GestureDetector(
      onTap: () => SwitchToLearningTabNotification().dispatch(context),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1520),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Soft background glow
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.09),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Level illustration
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _level!.imageAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.school_rounded,
                                  color: AppColors.primary, size: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Titles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Continue Learning',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$hub  ·  Level ${_level!.id}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _level!.title,
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Play button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_completed of $_total levels done',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
