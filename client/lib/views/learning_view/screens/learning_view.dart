import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/confetti_overlay.dart';
import 'package:communiq/common_widgets/level_path.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_router.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';

/// The path is one colour end to end: [AppColors.brand] for the level you can
/// play, success green for the ones you've finished, muted for locked. Cycling
/// hues per node would make the journey read as unrelated stops.
const _kNodeColor = AppColors.brand;

/// The learning journey: a winding path of levels, each unlocking the next,
/// grouped into themed journeys.
///
/// Progress is read from [LearningProgressStore], which the session screen
/// updates as each answer is graded — so a level's counter moves while the
/// user is still inside it, and the map is already correct when they return.
class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> {
  Curriculum? _curriculum;

  bool _loading = true;
  String? _loadError;
  bool _celebrate = false;

  final ScrollController _scroll = ScrollController();

  LearningProgressStore get _store => LearningProgressStore.instance;

  List<CommuniqLevel> get _levels => _curriculum?.levels ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final curriculum = await LevelService.instance.fetchCurriculum();
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
        _loading = false;
      });

      // Non-fatal: the store keeps whatever it already had and flags itself
      // stale, so the path still renders behind a retry banner.
      await _store.refresh();
      _scrollToCurrent();
    } catch (e) {
      debugPrint('[LearningView] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Gating ─────────────────────────────────────────────────────────────────
  //
  // Purely sequential: finish a level to open the next one. There used to be
  // an additional 450-coin wall in front of level 11, which was effectively
  // impassable — the written-response coins were never persisted server-side,
  // so the server's total topped out below the threshold no matter how well
  // the user did. Coins are a reward now, not a gate.

  int get _currentIndex {
    for (var i = 0; i < _levels.length; i++) {
      if (!_store.isComplete(_levels[i].id)) return i;
    }
    return _levels.length - 1;
  }

  bool _isLocked(int i) => i > 0 && !_store.isComplete(_levels[i - 1].id);

  LevelNodeState _stateFor(int i) {
    if (_store.isComplete(_levels[i].id)) return LevelNodeState.done;
    if (_isLocked(i)) return LevelNodeState.locked;
    return i == _currentIndex ? LevelNodeState.current : LevelNodeState.locked;
  }

  static const double _rowHeight = 148;

  void _scrollToCurrent() {
    if (!_scroll.hasClients || _levels.isEmpty) return;
    final target = (_currentIndex * _rowHeight - 220.0)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  void _onNodeTap(int i) {
    if (_isLocked(i)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finish "${_levels[i - 1].title}" first.'),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _openSheet(_levels[i]);
  }

  void _openSheet(CommuniqLevel level) {
    final journey = _curriculum?.journeyFor(level.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => _LevelSheet(
        level: level,
        journeyTitle: journey?.title ?? level.journeyTitle,
        isDone: _store.isComplete(level.id),
        stepsSolved: _store.stepsSolved(level.id),
        coinsEarned: _store.coinsFor(level.id),
        onStart: () {
          Navigator.pop(sheetContext);
          _startLevel(level);
        },
      ),
    );
  }

  Future<void> _startLevel(CommuniqLevel level) async {
    final wasDone = _store.isComplete(level.id);

    final result = await context.push<dynamic>(
      AppRoutes.learningSession,
      extra: LearningSessionArgs(
        level: level,
        isAlreadyCompleted: wasDone,
        initialCoins: _store.coins,
      ),
    );
    if (!mounted) return;

    // The session screen has already folded every graded answer into the
    // store, so the path is correct before this runs. Reconcile anyway — it
    // is the cheap way to pick up anything a failed request left behind.
    await _store.refresh();
    if (!mounted) return;

    final justFinished =
        result is Map && result['completed'] == true && !wasDone;
    if (justFinished) {
      setState(() => _celebrate = true);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _celebrate = false);
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      play: _celebrate,
      child: PlayfulBackground(
        seed: 2,
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: SafeArea(
            bottom: false,
            // Repaints whenever a graded answer lands, so progress is live.
            child: AnimatedBuilder(
              animation: _store,
              builder: (_, __) => _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingStateView(label: 'Loading your journey…');
    }

    if (_loadError != null && _levels.isEmpty) {
      return ErrorStateView(
        title: "Couldn't load lessons",
        message: _loadError,
        onRetry: _load,
      );
    }

    if (_levels.isEmpty) {
      return EmptyState(
        title: 'No lessons yet',
        message: 'Check back soon.',
        actionLabel: 'Reload',
        onAction: _load,
      );
    }

    final doneCount = _levels.where((l) => _store.isComplete(l.id)).length;

    return Column(
      children: [
        _Header(
          coins: _store.coins,
          doneCount: doneCount,
          total: _levels.length,
          syncFailed: _store.isStale,
          onRetrySync: _store.refresh,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () async {
              LevelService.instance.clearCache();
              await _load();
            },
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                top: AppSpacing.s16,
                bottom: AppSpacing.navClearance,
              ),
              itemCount: _levels.length,
              itemBuilder: (context, i) => _rowFor(i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowFor(int i) {
    final level = _levels[i];
    final journey = _curriculum?.journeyFor(level.id);

    // A banner introduces each journey, shown above its first level.
    final previousJourney =
        i == 0 ? null : _curriculum?.journeyFor(_levels[i - 1].id);
    final startsJourney = journey != null && journey.id != previousJourney?.id;

    final mcqCount = level.mcqs.length;
    final solved = _store.stepsSolved(level.id);
    final isDone = _store.isComplete(level.id);

    return _PathRow(
      index: i,
      isLast: i == _levels.length - 1,
      // A segment is "travelled" when the level above it is done. Both halves
      // of one segment must agree, so the incoming half of row i and the
      // outgoing half of row i-1 read the same level.
      trailReached: isDone,
      incomingReached: i > 0 && _store.isComplete(_levels[i - 1].id),
      level: level,
      color: _kNodeColor,
      state: _stateFor(i),
      coins: isDone ? _store.coinsFor(level.id) : null,
      // Partial progress, so a half-finished level reads as in progress
      // rather than untouched.
      progressLabel: !isDone && solved > 0 ? '$solved/${mcqCount + 1}' : null,
      rowHeight: _rowHeight,
      banner: startsJourney
          ? _JourneyBanner(
              journey: journey,
              doneInJourney: _levels
                  .where((l) =>
                      journey.contains(l.id) && _store.isComplete(l.id))
                  .length,
              totalInJourney:
                  _levels.where((l) => journey.contains(l.id)).length,
            )
          : null,
      onTap: () => _onNodeTap(i),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.coins,
    required this.doneCount,
    required this.total,
    required this.syncFailed,
    required this.onRetrySync,
  });

  final int coins;
  final int doneCount;
  final int total;
  final bool syncFailed;
  final VoidCallback onRetrySync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s12,
        AppSpacing.page,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LEARN', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 2),
                    Text('Your journey', style: AppTextStyles.displaySmall),
                  ],
                ),
              ),
              StatPill(
                icon: Icons.monetization_on_rounded,
                value: '$coins',
                color: AppColors.sun,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: ChunkyProgressBar(
                  value: total == 0 ? 0 : doneCount / total,
                  color: AppColors.success,
                  height: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Text('$doneCount/$total', style: AppTextStyles.labelMedium),
            ],
          ),
          if (syncFailed) ...[
            const SizedBox(height: AppSpacing.s10),
            GestureDetector(
              onTap: onRetrySync,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Showing saved progress — tap to retry.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── One row of the path ────────────────────────────────────────────────────

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.index,
    required this.isLast,
    required this.trailReached,
    required this.incomingReached,
    required this.level,
    required this.color,
    required this.state,
    required this.coins,
    required this.rowHeight,
    required this.onTap,
    this.progressLabel,
    this.banner,
  });

  final int index;
  final bool isLast;

  /// Whether this level is done — the outgoing trail segment is drawn as
  /// travelled only then, so the path visually stops where the user is.
  final bool trailReached;

  /// Whether the previous level is done, governing the incoming half.
  final bool incomingReached;

  final CommuniqLevel level;
  final Color color;
  final LevelNodeState state;
  final int? coins;

  /// "2/5" for a level in progress; null when untouched or finished.
  final String? progressLabel;

  final double rowHeight;
  final VoidCallback onTap;
  final Widget? banner;

  /// Horizontal placement, cycling left → centre → right → centre so the path
  /// visibly winds rather than running straight down.
  static double alignFor(int i) => switch (i % 4) {
        0 => -0.55,
        1 => 0.0,
        2 => 0.55,
        _ => 0.0,
      };

  double get _align => alignFor(index);

  @override
  Widget build(BuildContext context) {
    final locked = state == LevelNodeState.locked;

    return Column(
      children: [
        if (banner != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s16,
            ),
            child: banner!,
          ),
        SizedBox(
          height: rowHeight,
          child: Stack(
            children: [
              // The trail is painted behind the nodes. Each row draws its own
              // half-segments and meets its neighbour at the row boundary, so
              // nothing has to paint outside its bounds.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: LevelTrailPainter(
                      incomingFromAlign:
                          index == 0 ? null : alignFor(index - 1),
                      selfAlign: _align,
                      outgoingToAlign: isLast ? null : alignFor(index + 1),
                      incomingTravelled: incomingReached,
                      outgoingTravelled: trailReached,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(_align, 0),
                child: LevelNode(
                  index: index,
                  state: state,
                  color: color,
                  coins: coins,
                  onTap: onTap,
                ),
              ),
              // The level title sits opposite the node so the two never
              // overlap as the path winds.
              Align(
                alignment: Alignment(_align > 0 ? -0.92 : 0.92, 0),
                child: SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: _align > 0
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${level.emoji}  ${level.skill}',
                        textAlign:
                            _align > 0 ? TextAlign.left : TextAlign.right,
                        style: AppTextStyles.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.title,
                        textAlign:
                            _align > 0 ? TextAlign.left : TextAlign.right,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: locked ? AppColors.inkSoft : AppColors.ink,
                        ),
                      ),
                      if (progressLabel != null) ...[
                        const SizedBox(height: AppSpacing.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: AppRadius.pillRadius,
                            border:
                                Border.all(color: AppColors.brand, width: 1.5),
                          ),
                          child: Text(
                            'In progress · $progressLabel',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.brandDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Journey banner ─────────────────────────────────────────────────────────

/// Introduces each themed group of levels.
///
/// This replaces a coin-gated wall that could not be passed: the threshold was
/// checked against a server coin total that the written-response coins never
/// reached, because they were only ever added client-side.
class _JourneyBanner extends StatelessWidget {
  const _JourneyBanner({
    required this.journey,
    required this.doneInJourney,
    required this.totalInJourney,
  });

  final CommuniqJourney journey;
  final int doneInJourney;
  final int totalInJourney;

  @override
  Widget build(BuildContext context) {
    final complete = totalInJourney > 0 && doneInJourney == totalInJourney;

    return ChunkyCard(
      fill: complete ? AppColors.successSoft : AppColors.surfaceAlt,
      borderColor: complete ? AppColors.success : AppColors.sun,
      child: Row(
        children: [
          Text(journey.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(journey.title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  journey.subtitle.isNotEmpty
                      ? journey.subtitle
                      : '$doneInJourney of $totalInJourney complete',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: ChunkyProgressBar(
                        value: totalInJourney == 0
                            ? 0
                            : doneInJourney / totalInJourney,
                        color:
                            complete ? AppColors.success : AppColors.brand,
                        height: 10,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      '$doneInJourney/$totalInJourney',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level detail sheet ─────────────────────────────────────────────────────

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.level,
    required this.journeyTitle,
    required this.isDone,
    required this.stepsSolved,
    required this.coinsEarned,
    required this.onStart,
  });

  final CommuniqLevel level;
  final String journeyTitle;
  final bool isDone;
  final int stepsSolved;
  final int coinsEarned;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final inProgress = !isDone && stepsSolved > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(journeyTitle.toUpperCase(),
                        style: AppTextStyles.eyebrow),
                    const SizedBox(height: 2),
                    Text(level.title, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
              if (isDone)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 26),
            ],
          ),
          if (level.goal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              level.goal,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: AppRadius.chipRadius,
            ),
            child: Text(
              level.scenario,
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              _Chip(
                icon: Icons.quiz_rounded,
                label: '${level.mcqs.length} questions',
              ),
              const _Chip(icon: Icons.edit_rounded, label: '1 written answer'),
              if (coinsEarned > 0)
                _Chip(
                  icon: Icons.monetization_on_rounded,
                  label: '$coinsEarned earned',
                ),
            ],
          ),
          if (inProgress) ...[
            const SizedBox(height: AppSpacing.s14),
            ChunkyProgressBar(
              value: stepsSolved / level.totalSteps,
              color: AppColors.brand,
              height: 12,
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              '$stepsSolved of ${level.totalSteps} steps done — you can pick up '
              'where you left off.',
              style: AppTextStyles.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.s20),
          ChunkyButton(
            label: isDone
                ? 'Practise again'
                : inProgress
                    ? 'Resume level'
                    : 'Start level',
            icon: Icons.play_arrow_rounded,
            expand: true,
            variant: isDone
                ? ChunkyButtonVariant.secondary
                : ChunkyButtonVariant.primary,
            onPressed: onStart,
          ),
          if (isDone) ...[
            const SizedBox(height: AppSpacing.s8),
            Center(
              child: Text(
                'Replaying is free — and pays no coins.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.inkSoft),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSunk,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
