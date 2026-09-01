import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/confetti_overlay.dart';
import 'package:communiq/common_widgets/level_path.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_router.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/learning_service.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';

/// Minimum coins from Journey 1 required to unlock levels 11–20.
const _kMinCoinsForJourney2 = 450;

/// Where the two journeys split.
const _kJourney2StartIndex = 10;

/// Named hubs, one per level, shown on the node's detail sheet.
const _kHubNames = [
  'Introduction Hub', 'Conversation Hub', 'Professional Hub',
  'Influence Hub', 'Expression Hub', 'Pro Skills Hub',
  'Dialogue Hub', 'Office Hub', 'Social Hub', 'Work–Life Hub',
  'Crisis Hub', 'High-Stakes Hub', 'Leadership Hub',
  'Power Hub', 'Legacy Hub', 'Mastery Hub',
  'Elite Hub', 'Pinnacle Hub', 'Visionary Hub', 'Apex Hub',
];

/// Accent colour per level, cycled so adjacent nodes differ.
const _kNodeColors = [
  AppColors.grape,
  AppColors.teal,
  AppColors.coral,
  AppColors.info,
  AppColors.sun,
];

/// The learning journey: a winding path of levels, gated so each unlocks the
/// next, with a coin wall between the two journeys.
class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> {
  List<CommuniqLevel> _levels = [];
  Set<int> _done = {};
  Map<int, int> _levelCoins = {};
  int _totalCoins = 0;

  bool _loading = true;
  String? _loadError;

  /// True when the server reconciliation failed and cached progress is shown.
  bool _syncFailed = false;

  bool _celebrate = false;

  final ScrollController _scroll = ScrollController();

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
      final prefs = await SharedPreferences.getInstance();
      final levels = await LevelService.instance.fetchLevels();

      // Seed from cache for an instant first paint. This is read-only — the
      // server reconciliation below is what actually gates unlocks.
      final cachedDone = (prefs.getStringList('completed_level_ids') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

      if (!mounted) return;
      setState(() {
        _levels = levels;
        _done = cachedDone;
        _totalCoins = prefs.getInt('total_coins_cache') ?? 0;
        _levelCoins = {
          for (final id in cachedDone) id: prefs.getInt('level_${id}_coins') ?? 0,
        };
        _loading = false;
      });

      await _refreshFromServer();
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

  /// The server is the sole source of truth for anything that gates unlocks.
  /// A failure here is non-fatal — cached progress stays on screen behind a
  /// retry banner rather than blocking the tab.
  Future<void> _refreshFromServer() async {
    try {
      final progress = await LearningService.getProgress();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'completed_level_ids',
        progress.completedLevelIds.map((id) => '$id').toList(),
      );
      await prefs.setInt('total_coins_cache', progress.coins);

      if (!mounted) return;
      setState(() {
        _done = progress.completedLevelIds;
        _totalCoins = progress.coins;
        _syncFailed = false;
      });
    } catch (e) {
      debugPrint('[LearningView] progress sync failed, showing cache: $e');
      if (mounted) setState(() => _syncFailed = true);
    }
  }

  /// Index of the first level not yet completed.
  int get _currentIndex {
    for (var i = 0; i < _levels.length; i++) {
      if (!_done.contains(_levels[i].id)) return i;
    }
    return _levels.length - 1;
  }

  bool _isLocked(int i) {
    if (i == 0) return false;
    // Journey 2 additionally requires a coin threshold from Journey 1.
    if (i == _kJourney2StartIndex && _totalCoins < _kMinCoinsForJourney2) {
      return true;
    }
    return !_done.contains(_levels[i - 1].id);
  }

  LevelNodeState _stateFor(int i) {
    if (_done.contains(_levels[i].id)) return LevelNodeState.done;
    if (_isLocked(i)) return LevelNodeState.locked;
    return i == _currentIndex ? LevelNodeState.current : LevelNodeState.locked;
  }

  void _scrollToCurrent() {
    if (!_scroll.hasClients || _levels.isEmpty) return;
    // The path is laid out top-to-bottom, one row per level.
    final target = (_currentIndex * _rowHeight - 220.0)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  static const double _rowHeight = 148;

  void _onNodeTap(int i) {
    if (_isLocked(i)) {
      final needsCoins =
          i == _kJourney2StartIndex && _totalCoins < _kMinCoinsForJourney2;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsCoins
                ? 'Earn $_kMinCoinsForJourney2 coins in Journey 1 to unlock '
                    'Journey 2 — you have $_totalCoins.'
                : 'Finish the previous level first.',
          ),
        ),
      );
      return;
    }
    _openSheet(_levels[i], i);
  }

  void _openSheet(CommuniqLevel level, int index) {
    final isDone = _done.contains(level.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => _LevelSheet(
        level: level,
        hub: _kHubNames[index.clamp(0, _kHubNames.length - 1)],
        color: _kNodeColors[index % _kNodeColors.length],
        isDone: isDone,
        onStart: () async {
          Navigator.pop(sheetContext);
          final res = await context.push<dynamic>(
            AppRoutes.learningSession,
            extra: LearningSessionArgs(
              level: level,
              isAlreadyCompleted: isDone,
              initialCoins: _totalCoins,
            ),
          );
          if (res is Map) {
            final coins = res['coins'] as int? ?? 0;
            final score = res['score'] as int?;
            if (coins > 0) await _onLevelComplete(level, coins, score);
          }
        },
      ),
    );
  }

  Future<void> _onLevelComplete(
    CommuniqLevel level,
    int earnedCoins,
    int? aiScore,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Optimistic local update so the celebration is instant; the server
    // reconciliation immediately after is authoritative. The session screen
    // already called POST /learning/levels/:id/complete before returning.
    if (mounted) {
      setState(() {
        _done.add(level.id);
        _levelCoins[level.id] = earnedCoins;
        _celebrate = true;
      });
    }

    await prefs.setStringList(
      'completed_level_ids',
      _done.map((id) => '$id').toList(),
    );
    await prefs.setInt('level_${level.id}_coins', earnedCoins);
    if (aiScore != null) {
      await prefs.setInt('level_${level.id}_score', aiScore);
    }

    await _refreshFromServer();

    if (mounted) {
      // Reset the trigger so a later completion fires another burst.
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _celebrate = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      play: _celebrate,
      child: PlayfulBackground(
        seed: 2,
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: SafeArea(bottom: false, child: _body()),
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

    final doneCount = _levels.where((l) => _done.contains(l.id)).length;

    return Column(
      children: [
        _Header(
          coins: _totalCoins,
          doneCount: doneCount,
          total: _levels.length,
          syncFailed: _syncFailed,
          onRetrySync: _refreshFromServer,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(
              top: AppSpacing.s16,
              bottom: AppSpacing.navClearance,
            ),
            itemCount: _levels.length,
            itemBuilder: (context, i) => _PathRow(
              index: i,
              isLast: i == _levels.length - 1,
              // A segment is "travelled" when the level above it is done. Both
              // halves of one segment must agree, so the incoming half of row i
              // and the outgoing half of row i-1 read the same level.
              trailReached: _done.contains(_levels[i].id),
              incomingReached:
                  i > 0 && _done.contains(_levels[i - 1].id),
              level: _levels[i],
              hub: _kHubNames[i.clamp(0, _kHubNames.length - 1)],
              color: _kNodeColors[i % _kNodeColors.length],
              state: _stateFor(i),
              coins: _levelCoins[_levels[i].id],
              rowHeight: _rowHeight,
              // A visible gate between the two journeys, rather than a level
              // that silently refuses to open.
              gate: i == _kJourney2StartIndex
                  ? _JourneyGate(
                      unlocked: _totalCoins >= _kMinCoinsForJourney2,
                      coins: _totalCoins,
                      required: _kMinCoinsForJourney2,
                    )
                  : null,
              onTap: () => _onNodeTap(i),
            ),
          ),
        ),
      ],
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
    required this.hub,
    required this.color,
    required this.state,
    required this.coins,
    required this.rowHeight,
    required this.onTap,
    this.gate,
  });

  final int index;
  final bool isLast;

  /// Whether this level is done — the outgoing trail segment is drawn as
  /// travelled only then, so the path visually stops where the user is.
  final bool trailReached;

  /// Whether the previous level is done, governing the incoming half.
  final bool incomingReached;

  final CommuniqLevel level;
  final String hub;
  final Color color;
  final LevelNodeState state;
  final int? coins;
  final double rowHeight;
  final VoidCallback onTap;
  final Widget? gate;

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
    return Column(
      children: [
        if (gate != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s16,
            ),
            child: gate!,
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
                  width: 128,
                  child: Column(
                    crossAxisAlignment: _align > 0
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hub,
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
                          color: state == LevelNodeState.locked
                              ? AppColors.inkSoft
                              : AppColors.ink,
                        ),
                      ),
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

// ── Journey gate ───────────────────────────────────────────────────────────

class _JourneyGate extends StatelessWidget {
  const _JourneyGate({
    required this.unlocked,
    required this.coins,
    required this.required,
  });

  final bool unlocked;
  final int coins;
  // ignore: avoid_field_initializers_in_const_classes
  final int required;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      fill: unlocked ? AppColors.successSoft : AppColors.sunSoft,
      borderColor: unlocked ? AppColors.success : AppColors.sun,
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: unlocked ? AppColors.success : AppColors.sunDark,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Journey 2', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? 'Unlocked — keep going!'
                      : '$coins / $required coins to unlock',
                  style: AppTextStyles.bodySmall,
                ),
                if (!unlocked) ...[
                  const SizedBox(height: AppSpacing.s8),
                  ChunkyProgressBar(
                    value: coins / required,
                    color: AppColors.sun,
                    height: 10,
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

// ── Level detail sheet ─────────────────────────────────────────────────────

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.level,
    required this.hub,
    required this.color,
    required this.isDone,
    required this.onStart,
  });

  final CommuniqLevel level;
  final String hub;
  final Color color;
  final bool isDone;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Mascot(
                mood: isDone ? MascotMood.happy : MascotMood.thinking,
                size: 64,
                color: color,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hub, style: AppTextStyles.eyebrow),
                    const SizedBox(height: 2),
                    Text(level.title, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(level.scenario, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              _Chip(
                icon: Icons.quiz_rounded,
                label: '${level.mcqs.length} questions',
              ),
              const SizedBox(width: AppSpacing.s8),
              const _Chip(icon: Icons.mic_rounded, label: '1 spoken answer'),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          ChunkyButton(
            label: isDone ? 'Practise again' : 'Start level',
            icon: Icons.play_arrow_rounded,
            variant: isDone
                ? ChunkyButtonVariant.secondary
                : ChunkyButtonVariant.primary,
            onPressed: onStart,
          ),
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
