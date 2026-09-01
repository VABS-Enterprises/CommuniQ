import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import 'package:communiq/core/services/contest_service.dart';
import 'package:communiq/models/contest_models.dart';

/// Contest standings from `GET /contest/leaderboard`.
///
/// Distinct from the app-wide XP leaderboard reached from Home: the contest
/// tab previously showed that global board, which measured something else
/// entirely.
class ContestLeaderboardPage extends StatefulWidget {
  const ContestLeaderboardPage({super.key});

  @override
  State<ContestLeaderboardPage> createState() => _ContestLeaderboardPageState();
}

class _ContestLeaderboardPageState extends State<ContestLeaderboardPage> {
  /// null = all formats combined.
  ContestType? _filter;

  List<ContestRank> _rows = [];
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
      final rows = await ContestService.instance.leaderboard(type: _filter);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  void _setFilter(ContestType? t) {
    if (_filter == t) return;
    setState(() => _filter = t);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 11,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: const Text('Contest leaderboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == null,
                    color: AppColors.coral,
                    onTap: () => _setFilter(null),
                  ),
                  for (final t in ContestType.values)
                    _FilterChip(
                      label: t.label,
                      selected: _filter == t,
                      color: t.color,
                      onTap: () => _setFilter(t),
                    ),
                ],
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

    if (_error != null) {
      return ErrorStateView(message: _error, onRetry: _load);
    }

    if (_rows.isEmpty) {
      return const EmptyState(
        title: 'No scores yet',
        message: 'Be the first to enter this contest.',
        mood: MascotMood.encouraging,
      );
    }

    final myUid = AuthService.currentUser?.uid;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.coral,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s12,
          AppSpacing.page,
          AppSpacing.s32,
        ),
        itemCount: _rows.length,
        itemBuilder: (context, i) => FadeInUp(
          delay: AppMotion.staggerFor(i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
            child: _RankRow(
              row: _rows[i],
              isMe: myUid != null && _rows[i].userId == myUid,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: selected ? color : AppColors.outline,
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
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.isMe});

  final ContestRank row;
  final bool isMe;

  /// Podium colours for the top three; everyone else gets a neutral chip.
  Color get _rankColor => switch (row.rank) {
        1 => AppColors.gold,
        2 => AppColors.silver,
        3 => AppColors.bronze,
        _ => AppColors.bgSunk,
      };

  @override
  Widget build(BuildContext context) {
    final podium = row.rank <= 3;

    return ChunkyCard(
      selected: isMe,
      accent: AppColors.coral,
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
            child: Text(
              '${row.rank}',
              style: AppTextStyles.numeralSmall.copyWith(
                color: podium ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? '${row.name} (you)' : row.name,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(row.type.label, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '${row.score.round()}',
            style: AppTextStyles.numeralSmall.copyWith(
              color: AppColors.forScore(row.score),
            ),
          ),
        ],
      ),
    );
  }
}
