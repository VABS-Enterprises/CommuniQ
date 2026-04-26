import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';
import 'package:communiq/views/learning_view/screens/learning_session_screen.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/constants/api_constants.dart';

// ─── Node state ───────────────────────────────────────────────────────────────
enum _NodeState { completed, current, locked }

// ─── Journey metadata ─────────────────────────────────────────────────────────
const _kJourneySubtitles = [
  'Social Foundations',
  'Daily Conversations',
  'Building Connections',
  'Workplace Basics',
  'Express Yourself',
  'Professional Edge',
  'Advanced Dialogue',
  'Office Dynamics',
  'Social Mastery',
  'Work & Life',
  'Crisis & Conflict',
  'High-Stakes Talks',
  'Leadership Voice',
  'Power Dynamics',
  'Legacy Communication',
];

// Wave-curve offsets (index 0 = level 1 at bottom, index 9 = level 10 at top).
const _kWave = [
  0.48, // 0 → far right
  0.05, // 1 → slight right
  -0.38, // 2 → left
  -0.50, // 3 → far left
  -0.18, // 4 → center-left
  0.22, // 5 → center-right
  0.50, // 6 → far right
  0.30, // 7 → right
  -0.15, // 8 → slight left
  -0.48, // 9 → far left
];

const _kCyan = Color(0xFF00D2FF);
const _kOrange = Color(0xFFFF6B35);
const _kNodeSize = 82.0;
const _kPerJourney = 10;
const _kTotalLevels = 150;

// ─── Main widget ──────────────────────────────────────────────────────────────
class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView>
    with TickerProviderStateMixin {
  List<CommuniqLevel> _levels = [];
  Set<int> _completedIds = {};
  Map<int, int> _levelCoins = {};
  bool _isLoading = true;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _particleCtrl;

  // ── GlobalKeys for flying-animation targets ──────────────────────────────────
  final _profileBadgeKey = GlobalKey<_CircularXPBadgeState>();
  final _journeyXPKeys =
      List.generate(15, (_) => GlobalKey<_JourneyXPBarState>());

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();

    _load();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final levels = await LevelService.instance.fetchLevels();
      final prefs = await SharedPreferences.getInstance();
      
      Set<int> done = {};
      Map<int, int> coins = {};

      try {
        final response = await ApiService.get(ApiConstants.userProfile);
        final user = response['user'];
        if (user != null) {
          if (user['learning_progress'] != null) {
            final List<dynamic> progress = user['learning_progress'];
            for (var p in progress) {
              final id = p['id'] as int;
              done.add(id);
              coins[id] = p['coins'] as int;
            }
          }

          // Cache locally
          await prefs.setStringList('completed_level_ids', done.map((id) => id.toString()).toList());
          for (final id in done) {
             await prefs.setInt('level_${id}_coins', coins[id] ?? 30);
          }
        }
      } catch (e) {
        debugPrint('Failed to load profile from backend: $e');
        // Fallback to local cache
        done = (prefs.getStringList('completed_level_ids') ?? [])
            .map(int.parse)
            .toSet();
            
        for (final id in done) {
          coins[id] = prefs.getInt('level_${id}_coins') ?? 30;
        }
      }
      
      if (mounted) {
        setState(() {
          _levels = levels;
          _completedIds = done;
          _levelCoins = coins;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  int get _currentId {
    for (final l in _levels) {
      if (!_completedIds.contains(l.id)) return l.id;
    }
    return _levels.isEmpty ? 1 : _levels.last.id;
  }

  _NodeState _stateOf(int id) {
    final ji = (id - 1) ~/ _kPerJourney;
    if (_isJourneyLocked(ji)) return _NodeState.locked;

    if (_completedIds.contains(id)) return _NodeState.completed;
    if (id == _currentId) return _NodeState.current;
    return _NodeState.locked;
  }

  int _scoreFor(int id) {
    if (!_completedIds.contains(id)) return 0;
    // mock deterministic score for gamified UI testing
    return 30 + ((id * 47) % 71); // generates score between 30 and 100
  }

  int _starsForScore(int score) {
    if (score > 80) return 3;
    if (score > 50) return 2;
    if (score > 35) return 1;
    return 0;
  }

  int _starsInJourney(int ji) {
    final start = ji * _kPerJourney;
    final end = (start + _kPerJourney).clamp(0, _levels.length);
    if (start >= _levels.length) return 0;

    int stars = 0;
    for (int i = start; i < end; i++) {
      stars += _starsForScore(_scoreFor(_levels[i].id));
    }
    return stars;
  }

  int _coinsInJourney(int ji) {
    final start = ji * _kPerJourney;
    final end = (start + _kPerJourney).clamp(0, _levels.length);
    if (start >= _levels.length) return 0;

    int coins = 0;
    for (int i = start; i < end; i++) {
      final id = _levels[i].id;
      if (_completedIds.contains(id)) {
        coins += _levelCoins[id] ?? 30;
      }
    }
    return coins;
  }

  bool _isJourneyLocked(int ji) {
    if (ji == 0) return false;
    return _starsInJourney(ji - 1) < 20;
  }

  int _completedInJourney(int ji) {
    final start = ji * _kPerJourney;
    final end = (start + _kPerJourney).clamp(0, _levels.length);
    if (start >= _levels.length) return 0;
    return _levels
        .sublist(start, end)
        .where((l) => _completedIds.contains(l.id))
        .length;
  }

  String _personaFor(String category) {
    switch (category.toLowerCase()) {
      case 'professional':
      case 'leadership':
        return 'Strict Boss';
      default:
        return 'Friendly Mentor';
    }
  }

  // ─── Tap handling ──────────────────────────────────────────────────────────

  void _onTap(CommuniqLevel level) {
    final ji = (level.id - 1) ~/ _kPerJourney;
    if (_isJourneyLocked(ji)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Get 20 stars in Journey $ji to unlock this section!',
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ]),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_stateOf(level.id) == _NodeState.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.lock_rounded,
                color: AppColors.primaryLight, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Complete earlier scenarios to unlock this.',
                  style: TextStyle(color: AppColors.textPrimary)),
            ),
          ]),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _showSheet(level);
  }

  // ─── Flying XP animation ───────────────────────────────────────────────────

  void _launchChipToJourneyBar({required Offset src, required int ji, required int earnedCoins}) {
    final key = _journeyXPKeys[ji.clamp(0, 14)];
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final dest = box.localToGlobal(box.size.center(Offset.zero));
    
    // Launch 3 coins rapidly, dividing the earned coins evenly for the visual
    int perChip = (earnedCoins / 3).ceil();
    
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (!mounted) return;
        
        // Ensure the last chip makes the total exact if there's a remainder
        int displayAmount = (i == 2) ? (earnedCoins - (perChip * 2)) : perChip;
        if (displayAmount <= 0 && earnedCoins > 0) displayAmount = 1;

        OverlayEntry? e;
        e = OverlayEntry(
          builder: (_) => _FlyingXPChip(
            from: src,
            to: dest,
            label: '+$displayAmount',
            arcDir: i.isEven ? 1 : -1,
            onLanded: () => key.currentState?.onXPArrived(),
            onComplete: () => e?.remove(),
          ),
        );
        Overlay.of(context).insert(e);
      });
    }
  }

  /// Step 2 — when journey completes: turn bar green, then fire chips to profile ring.
  void _animateJourneyComplete({required int ji}) {
    _journeyXPKeys[ji.clamp(0, 14)].currentState?.onJourneyCompleted(
        onReadyToFly: () => _launchJourneyXPToProfile(ji: ji));
  }

  /// Step 3 — fire 5 staggered chips from the now-green journey bar to the profile circle.
  void _launchJourneyXPToProfile({required int ji}) {
    final jBox = _journeyXPKeys[ji.clamp(0, 14)]
        .currentContext
        ?.findRenderObject() as RenderBox?;
    final pBox =
        _profileBadgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (jBox == null || !jBox.attached || pBox == null || !pBox.attached)
      return;

    final src = jBox.localToGlobal(jBox.size.center(Offset.zero));
    final dest = pBox.localToGlobal(pBox.size.center(Offset.zero));
    final overlay = Overlay.of(context);

    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 110), () {
        if (!mounted) return;
        OverlayEntry? e;
        e = OverlayEntry(
          builder: (_) => _FlyingXPChip(
            from: src,
            to: dest,
            label: '+20 XP',
            arcDir: i.isEven ? 1 : -1,
            onLanded: i == 0
                ? () => _profileBadgeKey.currentState?.onXPArrived()
                : null,
            onComplete: () => e?.remove(),
          ),
        );
        overlay.insert(e);
      });
    }
  }

  /// Reloads completed IDs after returning from RoleplaySetupScreen, then fires
  /// the correct animations depending on what changed.
  Future<void> _reloadAndAnimate(
      {required int ji, required Set<int> prevCompleted, required int earnedCoins}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newDone = (prefs.getStringList('completed_level_ids') ?? [])
          .map(int.parse)
          .toSet();
          
      final Map<int, int> coins = {};
      for (final id in newDone) {
        coins[id] = prefs.getInt('level_${id}_coins') ?? 30;
      }
      
      if (!mounted) return;

      final newlyCompleted = newDone.difference(prevCompleted);
      setState(() {
        _completedIds = newDone;
        _levelCoins = coins;
      });

      if (newlyCompleted.isEmpty) return; // user quit without completing

      // Brief pause so the screen settles before the chip appears
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      // Source: centre of screen — feels like XP materialises from the session
      final sz = MediaQuery.of(context).size;
      final src = Offset(sz.width / 2, sz.height * 0.5);

      // Step 1: chip to journey bar
      _launchChipToJourneyBar(src: src, ji: ji, earnedCoins: earnedCoins);

      // Step 2: after chip lands, check if this journey just reached 10/10
      await Future.delayed(const Duration(milliseconds: 1050));
      if (!mounted) return;

      final prevJiCount =
          prevCompleted.where((id) => ((id - 1) ~/ _kPerJourney) == ji).length;
      final newJiCount =
          newDone.where((id) => ((id - 1) ~/ _kPerJourney) == ji).length;

      if (prevJiCount < _kPerJourney && newJiCount >= _kPerJourney) {
        _animateJourneyComplete(ji: ji);
      }
    } catch (_) {}
  }

  // ─── Bottom sheet ──────────────────────────────────────────────────────────

  void _showSheet(CommuniqLevel level) {
    final ji = ((level.id - 1) ~/ _kPerJourney).clamp(0, 14);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScenarioSheet(
        level: level,
        onStart: () {
          final prevCompleted = Set<int>.from(_completedIds);
          Navigator.pop(context);
          // Navigate immediately — no forced delay
          Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (_) => LearningSessionScreen(
                level: level,
                isAlreadyCompleted: _completedIds.contains(level.id),
              ),
            ),
            // On return, detect completion and fire the right animation
          ).then((coinsEarned) async {
            if (coinsEarned != null) {
              final prefs = await SharedPreferences.getInstance();
              final done = (prefs.getStringList('completed_level_ids') ?? []).map(int.parse).toSet();
              done.add(level.id);

              final coins = <int, int>{};
              for (final id in done) {
                if (id == level.id) {
                  coins[id] = coinsEarned;
                } else {
                  coins[id] = prefs.getInt('level_${id}_coins') ?? 30;
                }
              }

              // Update local cache
              await prefs.setStringList('completed_level_ids', done.map((id) => id.toString()).toList());
              await prefs.setInt('level_${level.id}_coins', coinsEarned);

              // Update backend
              try {
                final List<Map<String, dynamic>> progressList = [];
                for (final id in done) {
                  final lvl = _levels.firstWhere((l) => l.id == id, orElse: () => level);
                  progressList.add({
                    'id': id,
                    'scenario_name': lvl.title,
                    'journey_name': lvl.journeyTitle,
                    'journey_number': lvl.journeyId,
                    'coins': coins[id] ?? 30,
                  });
                }
                await ApiService.patch(ApiConstants.userProfile, body: {
                  'learning_progress': progressList,
                });
              } catch (e) {
                debugPrint('Failed to sync progress to backend: $e');
              }
            }
            _reloadAndAnimate(ji: ji, prevCompleted: prevCompleted, earnedCoins: coinsEarned ?? 0);
          });
        },
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.background
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  completedCount: _completedIds.length,
                  profileBadgeKey: _profileBadgeKey,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : _buildPath(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPath() {
    final totalJourneys = (_levels.length / _kPerJourney).ceil();
    return CustomScrollView(
      reverse: true,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
        for (int j = 0; j < totalJourneys; j++) ...[
          SliverToBoxAdapter(child: _buildJourneyNodes(j)),
          SliverToBoxAdapter(
            child: _JourneyHeader(
              index: j,
              subtitle: _kJourneySubtitles[j],
              completedInJourney: _completedInJourney(j),
              coinsEarned: _coinsInJourney(j),
              starsInJourney: _starsInJourney(j),
              isLocked: _isJourneyLocked(j),
              prevJourneyStars: j > 0 ? _starsInJourney(j - 1) : null,
              xpBarKey: _journeyXPKeys[j],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildJourneyNodes(int journeyIndex) {
    final start = journeyIndex * _kPerJourney;
    final end = (start + _kPerJourney).clamp(0, _levels.length);
    if (start >= _levels.length) return const SizedBox.shrink();
    final slice = _levels.sublist(start, end);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          for (int i = slice.length - 1; i >= 0; i--) ...[
            const SizedBox(height: 38),
            Align(
              alignment: Alignment(_kWave[i], 0),
              child: _NodeItem(
                level: slice[i],
                state: _stateOf(slice[i].id),
                score: _scoreFor(slice[i].id),
                glowAnim: _glowAnim,
                pulseAnim: _pulseAnim,
                particleCtrl: _particleCtrl,
                circleOnLeft: _kWave[i] < 0,
                staggerIndex: i,
                onTap: () => _onTap(slice[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int completedCount;
  final GlobalKey<_CircularXPBadgeState> profileBadgeKey;

  const _TopBar({required this.completedCount, required this.profileBadgeKey});

  @override
  Widget build(BuildContext context) {
    final streak = completedCount == 0 ? 1 : (completedCount ~/ 3) + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          // Streak pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text('$streak',
                    style: const TextStyle(
                        color: _kOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          const Spacer(),
          // Gradient title
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.primaryLight, _kCyan],
            ).createShader(b),
            child: const Text('CommuniQ',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ),
          const Spacer(),
          // Circular XP ring around profile icon
          _CircularXPBadge(
            key: profileBadgeKey,
            completed: completedCount ~/ _kPerJourney,
            total: _kTotalLevels ~/ _kPerJourney,
          ),
        ],
      ),
    );
  }
}

// ─── Circular XP badge (ring around profile icon) ─────────────────────────────
class _CircularXPBadge extends StatefulWidget {
  final int completed;
  final int total;
  const _CircularXPBadge(
      {super.key, required this.completed, required this.total});

  @override
  State<_CircularXPBadge> createState() => _CircularXPBadgeState();
}

class _CircularXPBadgeState extends State<_CircularXPBadge>
    with TickerProviderStateMixin {
  late final AnimationController _fillCtrl;
  late Animation<double>
      _fillAnim; // not final – can be replaced in didUpdateWidget

  late final AnimationController _hitCtrl;
  late final Animation<double> _hitScale;
  late final Animation<double> _hitGlow;

  @override
  void initState() {
    super.initState();
    final target = widget.total > 0 ? widget.completed / widget.total : 0.0;

    _fillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fillAnim = Tween<double>(begin: 0.0, end: target).animate(
        CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fillCtrl.forward();
    });

    _hitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _hitScale = Tween<double>(begin: 1.0, end: 1.28)
        .animate(CurvedAnimation(parent: _hitCtrl, curve: Curves.elasticOut));
    _hitGlow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _hitCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CircularXPBadge old) {
    super.didUpdateWidget(old);
    if (old.completed != widget.completed) {
      final target = widget.total > 0 ? widget.completed / widget.total : 0.0;
      final from = _fillAnim.value;
      _fillCtrl.reset();
      _fillAnim = Tween<double>(begin: from, end: target).animate(
          CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic));
      _fillCtrl.forward();
    }
  }

  /// Called from _FlyingXPChip when the chip lands on this badge.
  void onXPArrived() {
    if (!mounted) return;
    _hitCtrl.forward(from: 0).then((_) {
      if (mounted) _hitCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _hitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnim, _hitCtrl]),
      builder: (_, __) => Transform.scale(
        scale: _hitScale.value,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow backdrop when XP lands
              if (_hitGlow.value > 0.01)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: _hitGlow.value * 0.55),
                          blurRadius: 18,
                          spreadRadius: 5),
                      BoxShadow(
                          color:
                              _kCyan.withValues(alpha: _hitGlow.value * 0.35),
                          blurRadius: 10,
                          spreadRadius: 2),
                    ],
                  ),
                ),
              // Circular progress ring
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  value: _fillAnim.value,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.border.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(AppColors.primary, _kCyan,
                        (_fillAnim.value + 0.1).clamp(0, 1))!,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Profile icon inside ring
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Journey section header + per-journey XP bar ─────────────────────────────
class _JourneyHeader extends StatefulWidget {
  final int index;
  final String subtitle;
  final int completedInJourney;
  final int coinsEarned;
  final int starsInJourney;
  final bool isLocked;
  final int? prevJourneyStars;
  final GlobalKey<_JourneyXPBarState> xpBarKey;

  const _JourneyHeader({
    required this.index,
    required this.subtitle,
    required this.completedInJourney,
    required this.coinsEarned,
    required this.starsInJourney,
    required this.isLocked,
    this.prevJourneyStars,
    required this.xpBarKey,
  });

  @override
  State<_JourneyHeader> createState() => _JourneyHeaderState();
}

class _JourneyHeaderState extends State<_JourneyHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(-0.25, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    final delay = Duration(milliseconds: min(widget.index * 40, 300));
    Future.delayed(delay, () {
      if (mounted) _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Unified Header & XP Card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (widget.isLocked) ...[
                                      const Icon(Icons.lock_rounded,
                                          size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      'JOURNEY ${widget.index + 1}',
                                      style: TextStyle(
                                          color: widget.isLocked
                                              ? AppColors.textMuted
                                              : AppColors.primaryLight,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(widget.subtitle,
                                    style: TextStyle(
                                        color: widget.isLocked
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.isLocked
                                  ? AppColors.surface
                                  : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.starsInJourney} / 30',
                                  style: TextStyle(
                                      color: widget.isLocked
                                          ? AppColors.textMuted
                                          : AppColors.primaryLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.isLocked)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, right: 12),
                                child: Icon(Icons.lock_rounded,
                                    size: 24, color: AppColors.textMuted),
                              ),
                              Expanded(
                                child: Text(
                                  'Get 20 stars in Journey ${widget.index} to unlock this path (Current: ${widget.prevJourneyStars}/20)',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // ── Per-journey XP progress bar ──
                        _JourneyXPBar(
                          key: widget.xpBarKey,
                          completed: widget.completedInJourney,
                          coinsEarned: widget.coinsEarned,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Per-journey XP progress bar ─────────────────────────────────────────────
class _JourneyXPBar extends StatefulWidget {
  final int completed;
  final int coinsEarned;
  static const int total = _kPerJourney;

  const _JourneyXPBar({super.key, required this.completed, required this.coinsEarned});

  @override
  State<_JourneyXPBar> createState() => _JourneyXPBarState();
}

class _JourneyXPBarState extends State<_JourneyXPBar>
    with TickerProviderStateMixin {
  late final AnimationController _fillCtrl;
  late Animation<double> _fillAnim;

  // Glow pulse when a chip lands
  late final AnimationController _hitCtrl;
  late final Animation<double> _hitBorder;
  late final Animation<double> _hitGlow;

  // 0 → 1 transition to the green "Journey complete!" state
  late final AnimationController _completeCtrl;
  late final Animation<double> _completeAnim;

  @override
  void initState() {
    super.initState();
    final target = widget.completed / _JourneyXPBar.total;

    _fillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fillAnim = Tween<double>(begin: 0.0, end: target).animate(
        CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _fillCtrl.forward();
    });

    _hitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _hitBorder = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _hitCtrl, curve: Curves.easeOut));
    _hitGlow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _hitCtrl, curve: Curves.easeInOut));

    _completeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _completeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _completeCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_JourneyXPBar old) {
    super.didUpdateWidget(old);
    if (old.completed != widget.completed) {
      final target = widget.completed / _JourneyXPBar.total;
      final from = _fillAnim.value;
      _fillCtrl.reset();
      _fillAnim = Tween<double>(begin: from, end: target).animate(
          CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic));
      _fillCtrl.forward();
    }
  }

  /// Glow pulse when XP chip lands here.
  void onXPArrived() {
    if (!mounted) return;
    _hitCtrl.forward(from: 0).then((_) {
      if (mounted) _hitCtrl.reverse();
    });
  }

  /// Transition bar to green "Journey complete!" state.
  /// [onReadyToFly] is called after the animation settles, signalling that
  /// the caller should now fire chips from this bar to the profile circle.
  void onJourneyCompleted({required VoidCallback onReadyToFly}) {
    if (!mounted) return;
    _completeCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) onReadyToFly();
      });
    });
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _hitCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xpEarned = widget.completed * 20;
    const totalXP = _JourneyXPBar.total * 20;
    final cv = _completeAnim.value; // 0 → 1

    // Lerped colours: normal → green
    final bgColor = Color.lerp(AppColors.surface, const Color(0xFF0B2218), cv)!;
    final borderColor = Color.lerp(
        Color.lerp(
            AppColors.border, AppColors.primary, _hitBorder.value * 0.75)!,
        AppColors.success,
        cv)!;
    final shadowColor = Color.lerp(
        AppColors.primary.withValues(alpha: _hitGlow.value * 0.22),
        AppColors.success.withValues(alpha: 0.30),
        cv)!;

    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnim, _hitCtrl, _completeCtrl]),
      builder: (_, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _completeAnim.value > 0.1
              ? AppColors.success.withValues(alpha: _completeAnim.value * 0.15)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        // Cross-fade between normal content and completed content
        child: Stack(
          children: [
            // ── Normal state (fades out during first half of completion anim) ──
            Opacity(
              opacity: (1.0 - cv * 2).clamp(0.0, 1.0),
              child: Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('$xpEarned / $totalXP XP',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Text('🪙 ${widget.coinsEarned} / ${_JourneyXPBar.total * 20}',
                                    style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text(
                                '${widget.completed} / ${_JourneyXPBar.total} done',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _fillAnim.value,
                            minHeight: 5,
                            backgroundColor: AppColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.lerp(AppColors.primary, _kCyan,
                                  (_fillAnim.value + 0.15).clamp(0.0, 1.0))!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Completed state (fades in during second half) ─────────────────
            Opacity(
              opacity: (cv * 2 - 1.0).clamp(0.0, 1.0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.success, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Journey Complete! 🎉',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                            Text('$totalXP XP • 🪙 ${_JourneyXPBar.total * 30}',
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: const LinearProgressIndicator(
                            value: 1.0,
                            minHeight: 5,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.success),
                          ),
                        ),
                      ],
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

// ─── Single node item ─────────────────────────────────────────────────────────
class _NodeItem extends StatefulWidget {
  final CommuniqLevel level;
  final _NodeState state;
  final int score;
  final Animation<double> glowAnim;
  final Animation<double> pulseAnim;
  final AnimationController particleCtrl;
  final bool circleOnLeft;
  final int staggerIndex;
  final VoidCallback onTap;

  const _NodeItem({
    required this.level,
    required this.state,
    required this.score,
    required this.glowAnim,
    required this.pulseAnim,
    required this.particleCtrl,
    required this.circleOnLeft,
    required this.staggerIndex,
    required this.onTap,
  });

  @override
  State<_NodeItem> createState() => _NodeItemState();
}

class _NodeItemState extends State<_NodeItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.30), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.staggerIndex * 60), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => setState(() => _isPressed = true);
  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: widget.circleOnLeft
                  ? [
                      _buildCircleContent(),
                      const SizedBox(width: 12),
                      Flexible(child: _buildLabel())
                    ]
                  : [
                      Flexible(child: _buildLabel()),
                      const SizedBox(width: 12),
                      _buildCircleContent()
                    ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Stars ─────────────────────────────────────────────────────────────────

  Widget _buildStars(int score) {
    // Determine active stars
    int activeStars = 0;
    if (score > 80)
      activeStars = 3;
    else if (score > 50)
      activeStars = 2;
    else if (score > 35) activeStars = 1;

    Widget starIcon(bool active, double size) {
      return Icon(
        Icons.star_rounded,
        size: size,
        color: active ? const Color(0xFFFFD700) : AppColors.surface,
        shadows: active
            ? [
                Shadow(
                    color: Colors.orange.withValues(alpha: 0.8),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
                Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 2)),
              ]
            : [
                const Shadow(
                    color: Colors.black45, blurRadius: 2, offset: Offset(0, 1)),
              ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Transform.translate(
          offset: const Offset(8, -2),
          child: Transform.rotate(
            angle: -0.25,
            child: starIcon(activeStars >= 1, 18),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 2),
          child: starIcon(activeStars >= 2, 24),
        ),
        Transform.translate(
          offset: const Offset(-8, -2),
          child: Transform.rotate(
            angle: 0.25,
            child: starIcon(activeStars >= 3, 18),
          ),
        ),
      ],
    );
  }

  // ─── 3D Button ─────────────────────────────────────────────────────────────

  Widget _build3DButton({
    required Widget child,
    required Color primaryColor,
    required Color shadowColor,
    required Color borderColor,
    bool showSparkles = false,
    double reflectionAlpha = 0.5,
    Widget? topBadge,
    Widget? baseBadge,
  }) {
    final double depth = _isPressed ? 2.0 : 9.0;
    final double nodeHeight = _kNodeSize + 12;

    return SizedBox(
      width: _kNodeSize,
      height: nodeHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 3D Cylinder Body (Shadow)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            bottom: 0,
            child: Container(
              width: _kNodeSize,
              height: _kNodeSize +
                  depth -
                  1, // Stretches to connect bottom and top seamlessly
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kNodeSize / 2),
                  color: shadowColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 5),
                    )
                  ]),
            ),
          ),

          if (baseBadge != null)
            Positioned(
              bottom: -6,
              child: baseBadge,
            ),

          // Top face
          AnimatedPositioned(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            bottom: depth,
            child: Container(
              width: _kNodeSize,
              height: _kNodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.75, // slightly tighter highlight
                  colors: [
                    primaryColor.withValues(alpha: 0.85), // Lighter center
                    primaryColor,
                  ],
                ),
                border: Border.all(color: borderColor, width: 2.0),
              ),
              child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Glossy candy inner top reflection (elliptical for a more organic shine)
                    Positioned(
                      top: 3,
                      child: Container(
                        width: _kNodeSize * 0.6,
                        height: _kNodeSize * 0.3,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.elliptical(
                                _kNodeSize * 0.3, _kNodeSize * 0.15)),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: reflectionAlpha),
                                Colors.white.withValues(alpha: 0.0)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )),
                      ),
                    ),
                    // Bottom inner shadow for stronger 3D depth
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: _kNodeSize * 0.7,
                        height: _kNodeSize * 0.22,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.elliptical(
                                _kNodeSize * 0.35, _kNodeSize * 0.11)),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.3)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )),
                      ),
                    ),
                    child,

                    // Top badge securely bound to the moving face
                    if (topBadge != null)
                      Positioned(
                        right: -4,
                        bottom: 4,
                        child: topBadge,
                      ),
                  ]),
            ),
          ),
          if (showSparkles)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              bottom: depth,
              child: SizedBox(
                width: _kNodeSize,
                height: _kNodeSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (_kNodeSize - 110) / 2,
                      top: (_kNodeSize - 110) / 2,
                      child: _SparkleOverlay(controller: widget.particleCtrl),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Circle Content ────────────────────────────────────────────────────────

  Widget _buildCircleContent() {
    switch (widget.state) {
      // ── Current node ──────────────────────────────────────────────────────
      case _NodeState.current:
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer pulse rings for current node
            AnimatedBuilder(
              animation: widget.pulseAnim,
              builder: (_, __) {
                final scale = 1.0 + widget.pulseAnim.value * 0.6;
                final opacity = (1.0 - widget.pulseAnim.value) * 0.4;
                return Transform.translate(
                  offset: const Offset(0, -6),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: _kNodeSize,
                      height: _kNodeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: opacity),
                            width: 3),
                      ),
                    ),
                  ),
                );
              },
            ),
            _build3DButton(
              primaryColor: AppColors.primary,
              shadowColor: const Color(0xFF1336B5), // Deep blue shadow
              borderColor: _kCyan.withValues(alpha: 0.5),
              showSparkles: true,
              reflectionAlpha: 0.6,
              child: const Center(
                child: Text('START',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2)
                        ])),
              ),
            ),
          ],
        );

      // ── Completed node ────────────────────────────────────────────────────
      case _NodeState.completed:
        return _build3DButton(
          primaryColor: const Color(0xFF2A2346), // A gorgeous deep amethyst
          shadowColor: const Color(0xFF120E21),
          borderColor: const Color(0xFF63569D)
              .withValues(alpha: 0.8), // A vivid violet/indigo border
          reflectionAlpha: 0.25, // Subtler softer gloss reflection
          child: Center(
            child: Text(widget.level.categoryEmoji,
                style: const TextStyle(fontSize: 28, shadows: [
                  Shadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ])),
          ),
          topBadge: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF2A2346), width: 2), // matching border
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 14),
          ),
          baseBadge: _buildStars(widget.score),
        );

      // ── Locked node ───────────────────────────────────────────────────────
      case _NodeState.locked:
        return _build3DButton(
          primaryColor: const Color(0xFF1B1925), // Ultra dark deep slate
          shadowColor: const Color(0xFF09080C),
          borderColor: const Color(0xFF332F42),
          reflectionAlpha: 0.08, // Barely there matte finish
          child: Center(
            child: Opacity(
              opacity: 0.35,
              child: Text(widget.level.categoryEmoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
        );
    }
  }

  // ─── Label ─────────────────────────────────────────────────────────────────

  Widget _buildLabel() {
    final isLocked = widget.state == _NodeState.locked;
    final isCurrent = widget.state == _NodeState.current;

    return SizedBox(
      width: 120, // constrain width to force wrapping and maintain clean gap
      child: Column(
        crossAxisAlignment: widget.circleOnLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kCyan.withValues(alpha: 0.35)),
              ),
              child: const Text('+20 XP',
                  style: TextStyle(
                      color: _kCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          Text(
            widget.level.title,
            textAlign: widget.circleOnLeft ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              color: isLocked ? AppColors.textMuted : AppColors.textPrimary,
              fontSize: 13,
              height: 1.2,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Sparkle particles ────────────────────────────────────────────────────────
class _SparkleOverlay extends StatelessWidget {
  final AnimationController controller;
  const _SparkleOverlay({required this.controller});

  static final _sparks = <List<double>>[
    [0.30, 56.0, 0.00, 4.0],
    [1.70, 58.0, 0.18, 3.0],
    [2.90, 54.0, 0.36, 4.5],
    [4.30, 60.0, 0.54, 3.5],
    [5.50, 55.0, 0.72, 3.0],
    [0.95, 52.0, 0.09, 3.0],
  ];

  @override
  Widget build(BuildContext context) {
    const boxSize = 110.0;
    const center = boxSize / 2;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => SizedBox(
        width: boxSize,
        height: boxSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: _sparks.map((spark) {
            final angle = spark[0];
            final maxR = spark[1];
            final delay = spark[2];
            final dotSize = spark[3];

            final t = (controller.value + delay) % 1.0;
            final r = maxR * (0.30 + 0.70 * t);
            final opacity = t < 0.65 ? (1.0 - t / 0.65) * 0.85 : 0.0;

            final x = center + cos(angle) * r - dotSize / 2;
            final y = center + sin(angle) * r - dotSize / 2;

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t < 0.5 ? _kCyan : AppColors.primary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Flying "+20 XP" chip overlay animation ───────────────────────────────────
///
/// Rendered inside the global [Overlay] (which is a [Stack]).
/// Returns an [IgnorePointer] → [SizedBox.expand] → [Stack] → [Positioned] so
/// screen-coordinate placement works correctly without interferring with touches.
class _FlyingXPChip extends StatefulWidget {
  final Offset from;
  final Offset to;
  final String label; // text shown on the chip
  final int arcDir; // +1 or -1 — which side the arc bulges
  final VoidCallback? onLanded;
  final VoidCallback onComplete;

  const _FlyingXPChip({
    required this.from,
    required this.to,
    this.label = '+20 XP',
    this.arcDir = 1,
    this.onLanded,
    required this.onComplete,
  });

  @override
  State<_FlyingXPChip> createState() => _FlyingXPChipState();
}

class _FlyingXPChipState extends State<_FlyingXPChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _progress = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.72, 1.0)));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.25), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.65), weight: 75),
    ]).animate(_ctrl);

    // Fire onLanded at 78% travel
    _ctrl.addListener(() {
      if (!_landed && _ctrl.value >= 0.78) {
        _landed = true;
        widget.onLanded?.call();
      }
    });

    // Fire onComplete when done
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Quadratic Bézier arc between [widget.from] and [widget.to].
  Offset _arcAt(double t) {
    final p0 = widget.from;
    final p2 = widget.to;
    final dx = p2.dx - p0.dx;
    final dy = p2.dy - p0.dy;
    final len = sqrt(dx * dx + dy * dy);

    const arcH = 140.0; // steeper/wider perpendicular bulge
    final nx = len > 0 ? (-dy / len) * widget.arcDir : 0.0;
    final ny = len > 0 ? (dx / len) * widget.arcDir : 0.0;

    final cpX = (p0.dx + p2.dx) / 2 + nx * arcH;
    final cpY = (p0.dy + p2.dy) / 2 + ny * arcH;

    final mt = 1 - t;
    return Offset(
      mt * mt * p0.dx + 2 * mt * t * cpX + t * t * p2.dx,
      mt * mt * p0.dy + 2 * mt * t * cpY + t * t * p2.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pos = _arcAt(_progress.value);
        // Chip is ~62 × 26 px; offset so the arc point is its centre.
        const halfW = 31.0;
        const halfH = 13.0;

        return IgnorePointer(
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned(
                  left: pos.dx - halfW,
                  top: pos.dy - halfH,
                  child: Opacity(
                    opacity: _fade.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, _kCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.55),
                                blurRadius: 10,
                                spreadRadius: 1),
                            BoxShadow(
                                color: _kCyan.withValues(alpha: 0.30),
                                blurRadius: 6),
                          ],
                        ),
                        child: Text(widget.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Scenario bottom sheet ────────────────────────────────────────────────────
class _ScenarioSheet extends StatefulWidget {
  final CommuniqLevel level;
  final VoidCallback onStart;

  const _ScenarioSheet({required this.level, required this.onStart});

  @override
  State<_ScenarioSheet> createState() => _ScenarioSheetState();
}

class _ScenarioSheetState extends State<_ScenarioSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),

          // Category emoji — elastic pop
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, _kCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                  child: Text(widget.level.categoryEmoji,
                      style: const TextStyle(fontSize: 28))),
            ),
          ),
          const SizedBox(height: 14),

          FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // XP badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Text('+20 XP',
                      style: TextStyle(
                          color: _kCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(height: 10),

                // Full title (sheet shows complete name)
                Text(widget.level.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),

                Text(widget.level.scenario,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(widget.level.journeyTitle,
                      style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 20),

                Divider(color: AppColors.border),
                const SizedBox(height: 14),

                // Challenge card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR CHALLENGE',
                          style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4)),
                      const SizedBox(height: 8),
                      Text(widget.level.responsePrompt,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Start button — passes its OWN context to onStart for position lookup
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, _kCyan],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      onPressed: widget.onStart,
                      style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text('Start Scenario',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
