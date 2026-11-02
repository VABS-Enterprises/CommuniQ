import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/core/services/offline_cache_service.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/core/services/leaderboard_service.dart';

/// App-wide XP standings (GET /leaderboard, GET /leaderboard/weekly).
///
/// "All time" ranks total XP; "This week" ranks XP earned in the current
/// (Monday-start) week. The contest tab has its own separate board that ranks
/// contest scores.
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
  final RequestSequencer _requests = RequestSequencer();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ticket = _requests.next();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = _weekly
          ? await LeaderboardService.fetchWeekly()
          : await LeaderboardService.fetchAllTime();
      // A newer load (the user toggled again) owns the screen now.
      if (!mounted || !_requests.isCurrent(ticket)) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LeaderboardPage] load failed: $e');
      if (!mounted || !_requests.isCurrent(ticket)) return;
      setState(() {
        _error = 'Could not load the leaderboard.';
        _loading = false;
      });
    }
  }

  void _setWeekly(bool weekly) {
    if (_weekly == weekly) return;
    setState(() => _weekly = weekly);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 12,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: const Text('Leaderboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Toggle(
                      label: 'All time',
                      selected: !_weekly,
                      onTap: () => _setWeekly(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: _Toggle(
                      label: 'This week',
                      selected: _weekly,
                      onTap: () => _setWeekly(true),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.s4,
              ),
              child: Text(
                _weekly
                    ? "Ranked by this week's XP · resets every Monday"
                    : 'Ranked by total XP',
                style: AppTextStyles.bodySmall,
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    if (_error != null) return ErrorStateView(message: _error, onRetry: _load);

    if (_entries.isEmpty) {
      return EmptyState(
        title: _weekly ? 'Nothing this week' : 'No rankings yet',
        message: _weekly
            ? 'Nobody has earned XP yet this week. Finish a session to '
                'lead the board.'
            : 'Finish a session to get on the board.',
        mood: MascotMood.encouraging,
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    final myUid = AuthService.currentUser?.uid;

    return RefreshIndicator(
      onRefresh: () {
        // Pull-to-refresh must reach the server, not reuse the last minute.
        OfflineCacheService.invalidateFresh();
        return _load();
      },
      color: AppColors.brand,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s8,
          AppSpacing.page,
          AppSpacing.s32,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final e = _entries[i];
          return FadeInUp(
            delay: AppMotion.staggerFor(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s10),
              child: LeaderboardRow(
                rank: i + 1,
                name: e.name,
                trailing: _weekly ? '${e.xp} XP this week' : '${e.xp} XP',
                isMe: myUid != null && myUid == e.uid,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.outline,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? AppColors.inkOnDark : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// One ranked row. Shared shape for any standings list.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.trailing,
    required this.isMe,
  });

  final int rank;
  final String name;
  final String trailing;
  final bool isMe;

  Color get _rankColor => switch (rank) {
        1 => AppColors.gold,
        2 => AppColors.silver,
        3 => AppColors.bronze,
        _ => AppColors.bgSunk,
      };

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      selected: isMe,
      accent: AppColors.brand,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor,
              shape: BoxShape.circle,
            ),
            child: rank <= 3
                ? const Icon(Icons.emoji_events_rounded,
                    size: 19, color: AppColors.ink)
                : Text(
                    '$rank',
                    style: AppTextStyles.numeralSmall
                        .copyWith(color: AppColors.inkMuted),
                  ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              isMe ? '$name (you)' : name,
              style: AppTextStyles.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            trailing,
            style: AppTextStyles.numeralSmall.copyWith(color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}
