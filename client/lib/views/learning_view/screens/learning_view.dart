import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';
import 'package:communiq/views/learning_view/screens/learning_session_screen.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

const _kBg        = Color(0xFF050816);
const _kSurface   = Color(0xFF0F172A);
const _kBorder    = Color(0x1AFFFFFF);
const _kPath      = Color(0xFF5B52F0);
const _kPathLight = Color(0xFF818CF8);

// Hub illustrations are now managed via CommuniqLevel.imageAsset getter

class _Hub {
  final String name;
  final Color  glow;
  final Color  dark;
  const _Hub(this.name, this.glow, this.dark);
}

const _kHubs = [
  _Hub('Introduction Hub', Color(0xFF7835FF), Color(0xFF0C0A20)),
  _Hub('Conversation Hub', Color(0xFF00CCFF), Color(0xFF060D1A)),
  _Hub('Professional Hub', Color(0xFF7C5CFF), Color(0xFF0C0A20)),
  _Hub('Influence Hub',    Color(0xFF00CCFF), Color(0xFF060B1A)),
  _Hub('Expression Hub',   Color(0xFFA78BFA), Color(0xFF0C0820)),
  _Hub('Pro Skills Hub',   Color(0xFF7835FF), Color(0xFF0C0A20)),
  _Hub('Dialogue Hub',     Color(0xFF00CCFF), Color(0xFF060D1A)),
  _Hub('Office Hub',       Color(0xFF7C5CFF), Color(0xFF0C0A20)),
  _Hub('Social Hub',       Color(0xFFA78BFA), Color(0xFF0C0820)),
  _Hub('Work–Life Hub',    Color(0xFF00CCFF), Color(0xFF060B1A)),
  _Hub('Crisis Hub',       Color(0xFF7835FF), Color(0xFF0C0A20)),
  _Hub('High-Stakes Hub',  Color(0xFF7C5CFF), Color(0xFF0C0A20)),
  _Hub('Leadership Hub',   Color(0xFFA78BFA), Color(0xFF0C0820)),
  _Hub('Power Hub',        Color(0xFF00CCFF), Color(0xFF060D1A)),
  _Hub('Legacy Hub',       Color(0xFF7835FF), Color(0xFF0C0A20)),
  _Hub('Mastery Hub',      Color(0xFFA78BFA), Color(0xFF0C0820)),
  _Hub('Elite Hub',        Color(0xFF00CCFF), Color(0xFF060D1A)),
  _Hub('Pinnacle Hub',     Color(0xFF7C5CFF), Color(0xFF0C0A20)),
  _Hub('Visionary Hub',    Color(0xFF7835FF), Color(0xFF0C0A20)),
  _Hub('Apex Hub',         Color(0xFF00CCFF), Color(0xFF060D1A)),
];

// ═══════════════════════════════════════════════════════════════════════════════
// LAYOUT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const _kPerHub  = 1;
const _kTLevels = 20;
const _kCW      = 234.0;
const _kCH      = 162.0;
const _kZone    = 380.0;
const _kTopPad  = 300.0;   // Extra top padding so milestone2 card fits above scenario 20
const _kBotPad  = 160.0;
const _kMilestoneGap = 220.0;
// Minimum coins needed to unlock Journey 2 (scenarios 11-20)
const _kMinCoinsForJourney2 = 450;

enum _HS { active, locked, completed }

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class LearningView extends StatefulWidget {
  const LearningView({super.key});
  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> with TickerProviderStateMixin {
  final GlobalKey _coinKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _milestone1Key = GlobalKey();
  final GlobalKey _milestone2Key = GlobalKey();

  List<CommuniqLevel> _levels  = [];
  Set<int>            _done    = {};
  bool                _loading = true;
  int                 _totalCoins = 0; 
  Map<int, int>       _levelCoins = {}; // Tracking actual coins per level

  late final AnimationController _shimCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  double _sw = 0, _ch = 0;
  int    _n  = 0;
  final Map<int,Offset> _hubPos  = {};
  final List<Offset>    _pathPts = [];
  final ScrollController _scroll = ScrollController();
  bool _needsScrollToCur = false; // set true when we need to jump to current scenario

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _shimCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _load();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _shimCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p    = await SharedPreferences.getInstance();
      // await p.clear(); // <--- SIMPLE CODE LINE TO RESET (Active for testing)
      
      final lvls = await LevelService.instance.fetchLevels();
      final doneIds = (p.getStringList('completed_level_ids') ?? []).map(int.parse).toSet();
      int total = 0;
      Map<int, int> lCoins = {};
      for (final id in doneIds) {
        final c = p.getInt('level_${id}_coins') ?? 0;
        total += c;
        lCoins[id] = c;
      }
      if (mounted) {
        setState(() {
          _levels = lvls;
          _done = doneIds;
          _totalCoins = total;
          _levelCoins = lCoins;
          _loading = false;
          _needsScrollToCur = true;
          _sw = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _milestone1Y = 0;
  double _milestone2Y = 0;

  void _layout(double w) {
    if (_sw == w && _hubPos.isNotEmpty) return;
    _sw = w;
    _n  = _levels.length;
    // Canvas height: scenarios + two milestone gaps (one between 10/11, one above 20)
    _ch = _n * _kZone + _kTopPad + _kBotPad + _kMilestoneGap * 2;
    _hubPos.clear();
    _pathPts.clear();

    for (int j = 0; j < _n; j++) {
      // offset increases from bottom (j=0) to top (j=n-1)
      double offset = j * _kZone;
      // Add gap for scenarios 11-20 (j >= 10), to make room for milestone1 card
      if (j >= 10) offset += _kMilestoneGap;

      final y = _ch - _kBotPad - offset - _kZone * 0.5;
      final x = j.isEven ? w * 0.33 : w * 0.67;

      _hubPos[j] = Offset(x, y);
      _pathPts.add(Offset(x, y));

      // Milestone 1: sits in the gap between scenario 9 (j=9) and scenario 10 (j=10)
      if (j == 9) {
        // midpoint of the gap between j=9 and j=10
        _milestone1Y = y - _kZone * 0.5 - _kMilestoneGap * 0.5;
      }
    }

    // Milestone 2: sits in the top padding area ABOVE the final scenario
    if (_hubPos.containsKey(_n - 1)) {
      // Position it significantly higher to avoid any overlap with the scenario icon/title
      _milestone2Y = _hubPos[_n - 1]!.dy - _kZone * 0.8 - _kMilestoneGap * 0.5;
    }
  }

  int get _curIdx {
    if (_levels.isEmpty || _n == 0) return 0;
    final id = _curId;
    return ((id - 1) ~/ _kPerHub).clamp(0, _n - 1);
  }

  int get _curId {
    for (final l in _levels) {
      if (!_done.contains(l.id)) return l.id;
    }
    return _levels.isEmpty ? 1 : _levels.last.id;
  }

  bool _isLocked(int j) {
    if (j == 0) return false;
    // Scenarios 11-20 (index 10-19) require Journey 1 completion with 450+ coins
    if (j == 10) return _totalCoins < _kMinCoinsForJourney2;
    return _comp(j - 1) < _kPerHub;
  }

  int _comp(int j) {
    final s = j * _kPerHub, e = (s + _kPerHub).clamp(0, _levels.length);
    if (s >= _levels.length) return 0;
    return _levels.sublist(s, e).where((l) => _done.contains(l.id)).length;
  }

  void _scrollToCur() {
    if (!_scroll.hasClients) return;
    if (_hubPos.isEmpty) return;
    final pos = _hubPos[_curIdx];
    if (pos == null) return;
    final vh = _scroll.position.viewportDimension;
    final mx = _scroll.position.maxScrollExtent;
    // Centre the current scenario in the viewport with a slight upward offset
    final target = (pos.dy - vh * 0.45).clamp(0.0, mx);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic);
  }

  void _tap(int j) {
    if (_isLocked(j)) {
      if (j == 10 && _totalCoins < _kMinCoinsForJourney2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Earn at least $_kMinCoinsForJourney2 coins in Journey 1 to unlock Journey 2! (You have $_totalCoins)', style: const TextStyle(color: Colors.white)),
          backgroundColor: _kSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kBorder)),
          duration: const Duration(seconds: 3),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Complete the previous scenario first', style: TextStyle(color: Colors.white)),
          backgroundColor: _kSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kBorder)),
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }
    final lvl = _levels[j];
    _openSheet(lvl);
  }

  void _openSheet(CommuniqLevel level) {
    final isDone = _done.contains(level.id);
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        level: level,
        onStart: () async {
        Navigator.pop(context);
        final res = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(builder: (_) => LearningSessionScreen(level: level, isAlreadyCompleted: isDone)),
        );
        if (res != null && res is Map) {
          final coins = res['coins'] as int? ?? 0;
          final score = res['score'] as int?;
          if (coins > 0) {
            _onLevelComplete(level, coins, score);
          }
        }
      },
      ),
    );
  }

  void _onLevelComplete(CommuniqLevel level, int earnedCoins, int? aiScore) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _done.add(level.id);
      _totalCoins += earnedCoins;
      _levelCoins[level.id] = earnedCoins;
      _needsScrollToCur = true; 
      _sw = 0; 
    });
    await prefs.setStringList('completed_level_ids', _done.map((id) => id.toString()).toList());
    await prefs.setInt('level_${level.id}_coins', earnedCoins);
    if (aiScore != null) {
      await prefs.setInt('level_${level.id}_score', aiScore);
    }

    // Fly particles to milestone 1 for levels 1-10, milestone 2 for 11-20
    final milestoneKey = level.id <= 10 ? _milestone1Key : _milestone2Key;
    _flyParticles(icon: '✨', targetKey: milestoneKey, count: 5);
    _flyParticles(icon: '🪙', targetKey: _coinKey, count: 3);

    if (level.id == 20) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _flyParticles(icon: '✨', targetKey: _profileKey, count: 15, isBig: true);
      });
    }

    try {
      final List<Map<String, dynamic>> progressList = [];
      for (final id in _done) {
        final lvl = _levels.firstWhere((l) => l.id == id, orElse: () => level);
        progressList.add({
          'id': id,
          'scenario_name': lvl.title,
          'journey_name': lvl.journeyTitle,
          'journey_number': lvl.journeyId,
          'coins': prefs.getInt('level_${id}_coins') ?? 60,
          'ai_evaluated_score': prefs.getInt('level_${id}_score'),
        });
      }
      await ApiService.patch(ApiConstants.userProfile, body: {'learning_progress': progressList});
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  void _flyParticles({required String icon, required GlobalKey targetKey, int count = 5, bool isBig = false}) {
    final RenderBox? targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;
    final targetPos = targetBox.localToGlobal(Offset.zero) + Offset(targetBox.size.width / 2, targetBox.size.height / 2);
    final screenSize = MediaQuery.of(context).size;
    final sourcePos = Offset(screenSize.width / 2, screenSize.height * 0.8);
    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        _showFlyingIcon(icon, sourcePos, targetPos, isBig);
      });
    }
  }

  void _showFlyingIcon(String icon, Offset start, Offset end, bool isBig) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingParticle(
        icon: icon, start: start, end: end, isBig: isBig,
        onComplete: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_loading && _levels.isNotEmpty;
    final pct  = (_kTLevels > 0 ? _done.length / _kTLevels : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Layers (Manual Replicate of SkyCampusBackground without SafeArea)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1128), Color(0xFF060918), Color(0xFF020617)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [const Color(0xFF5B52F0).withValues(alpha: 0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              _Header(pct: pct, coinKey: _coinKey, profileKey: _profileKey, totalCoins: _totalCoins),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _kPath))
                    : _buildMap(_done.length),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMap(int activeIdx) {
    // Count done in each journey
    final j1Done = _done.where((id) => id >= 1 && id <= 10).length;
    final j2Done = _done.where((id) => id >= 11 && id <= 20).length;
    final j1Xp   = j1Done * 20;
    final j2Xp   = j2Done * 20;
    final j1Coins = _done.where((id) => id >= 1 && id <= 10).fold(0, (sum, id) => sum + (_levelCoins[id] ?? 0));

    // Derive journey titles directly from the level data (no hardcoding)
    final j1Title = _levels.isNotEmpty ? _levels[0].journeyTitle : 'Journey 1';
    final j2Title = _levels.length > 10 ? _levels[10].journeyTitle : 'Journey 2';

    return LayoutBuilder(builder: (_, box) {
      _layout(box.maxWidth);
      // Once layout populates _hubPos, scroll to the current scenario
      if (_needsScrollToCur && _hubPos.isNotEmpty) {
        _needsScrollToCur = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCur());
      }
      return SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: _sw, height: _ch,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _shimCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _PathPaint(_pathPts, _shimCtrl.value, activeIdx),
                  ),
                ),
              ),
              for (int j = 0; j < _n; j++)
                if (_hubPos.containsKey(j)) _buildHub(j),
              
              // Journey 1 milestone card — appears between scenario 10 and 11
              if (_n >= 10)
                Positioned(
                  key: _milestone1Key,
                  top: _milestone1Y - 100, // Shifted up to center the card in the gap
                  left: 0, right: 0,
                  child: _MilestoneCard(
                    journeyNumber: 1,
                    journeyTitle: j1Title,
                    xpEarned: j1Xp,
                    xpTotal: 200,
                    coinsEarned: j1Coins,
                    doneCount: j1Done,
                    totalCount: 10,
                    unlocked: true,
                  ),
                ),

              // Journey 2 milestone card — appears after all 20 scenarios
              if (_n >= 20)
                Positioned(
                  key: _milestone2Key,
                  top: _milestone2Y - 100, // Shifted up to center the card in the gap
                  left: 0, right: 0,
                  child: _MilestoneCard(
                    journeyNumber: 2,
                    journeyTitle: j2Title,
                    xpEarned: j2Xp,
                    xpTotal: 200,
                    coinsEarned: _totalCoins - j1Coins,
                    doneCount: j2Done,
                    totalCount: 10,
                    unlocked: _totalCoins >= _kMinCoinsForJourney2,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHub(int j) {
    final level    = _levels[j];
    final center   = _hubPos[j]!;
    final st       = _done.contains(level.id) ? _HS.completed : (j == _curIdx ? _HS.active : _HS.locked);
    final def      = _kHubs[j % _kHubs.length];
    final illo     = level.imageAsset;
    final isLeft   = j.isEven;
    final isActive = st == _HS.active;
    final isLocked = st == _HS.locked;
    final isDone   = st == _HS.completed;

    final hubWidth = _kCW + 160; // Tighter space for side title
    final leftPos = isLeft ? center.dx - _kCW / 2 : center.dx - _kCW / 2 - 160;

    return Positioned(
      left: leftPos,
      top:  center.dy - _kCH / 2 - 25,
      child: GestureDetector(
        onTap: () => _tap(j),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) {
            final gv = isActive ? _glowAnim.value : (isLocked ? 0.0 : 0.45);
            
            Widget title = Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: SizedBox(
                width: 150,
                child: Text(level.title.toUpperCase(),
                  textAlign: isLeft ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    color: isActive ? def.glow : Colors.white,
                    fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6,
                    height: 1.2,
                    shadows: isActive ? [Shadow(color: def.glow.withValues(alpha: 0.8), blurRadius: 12)] : null,
                  ),
                ),
              ),
            );

            Widget hub = _HubCard(illoPath: illo, glow: def.glow, isActive: isActive, isLocked: isLocked, isDone: isDone, glowVal: gv);

            return SizedBox(
              width: hubWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: isLeft 
                  ? [
                      hub, 
                      Transform.translate(
                        offset: const Offset(-20, 0),
                        child: title,
                      )
                    ]
                  : [
                      Transform.translate(
                        offset: const Offset(20, 0),
                        child: title,
                      ), 
                      hub
                    ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String illoPath;
  final Color  glow;
  final bool   isActive, isLocked, isDone;
  final double glowVal;
  const _HubCard({required this.illoPath, required this.glow, required this.isActive, required this.isLocked, required this.isDone, required this.glowVal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kCW, height: _kCH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (!isLocked && (isActive || glowVal > 0.2))
            Positioned(
              top: _kCH * 0.2, left: _kCW * 0.1,
              child: Container(
                width: _kCW * 0.8, height: _kCH * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: glow.withValues(alpha: glowVal * (isActive ? 0.45 : 0.15)), blurRadius: isActive ? 40 : 18, spreadRadius: isActive ? 12 : 4)],
                ),
              ),
            ),
          Opacity(
            opacity: isLocked ? 0.35 : 1.0,
            child: ShaderMask(
              shaderCallback: (Rect bounds) => RadialGradient(
                colors: [Colors.white, Colors.white.withValues(alpha: 0.15), Colors.transparent],
                stops: const [0.45, 0.85, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Image.asset(illoPath, width: _kCW, height: _kCH, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: glow.withValues(alpha: 0.4), size: 48)),
            ),
          ),
          if (isLocked) const Icon(Icons.lock_rounded, color: Colors.white38, size: 30),
          if (isDone) Positioned(top: 15, right: 15, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green, border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5)), child: const Icon(Icons.check_rounded, color: Colors.white, size: 14))),
        ],
      ),
    );
  }
}

class _PathPaint extends CustomPainter {
  final List<Offset> pts;
  final double shimmer;
  final int activeIdx;
  const _PathPaint(this.pts, this.shimmer, this.activeIdx);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;

    final paint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_kPath, _kPathLight, const Color(0xFF00CCFF)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final fullPath = Path();
    for (int i = 0; i < pts.length - 1; i++) {
      if (i == 9) continue;
      final p1 = pts[i], p2 = pts[i + 1];
      fullPath.moveTo(p1.dx, p1.dy);
      final my = (p1.dy + p2.dy) / 2;
      fullPath.cubicTo(p1.dx, my, p2.dx, my, p2.dx, p2.dy);
    }
    
    // Background path
    canvas.drawPath(fullPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round);

    final activePath = Path();
    for (int i = 0; i < min(activeIdx, pts.length - 1); i++) {
      if (i == 9) continue;
      final p1 = pts[i], p2 = pts[i + 1];
      activePath.moveTo(p1.dx, p1.dy);
      final my = (p1.dy + p2.dy) / 2;
      activePath.cubicTo(p1.dx, my, p2.dx, my, p2.dx, p2.dy);
    }
    
    // Path glow - very subtle and tight
    canvas.drawPath(activePath, Paint()
      ..color = _kPath.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..strokeCap = StrokeCap.round);
    
    // Core path line - elegant 3.5 width
    canvas.drawPath(activePath, paint..strokeWidth = 3.5);

    // Flowing shimmer effect across all segments - more subtle
    final metrics = activePath.computeMetrics();
    for (final pm in metrics) {
      final len = pm.length;
      if (len < 5) continue;

      // Subtle flowing light segment
      final s0 = (shimmer * 1.5 * len) % len;
      final s1 = (s0 + 100).clamp(0.0, len);
      
      if (s1 > s0) {
        canvas.drawPath(
          pm.extractPath(s0, s1),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PathPaint old) => old.shimmer != shimmer || old.activeIdx != activeIdx;
}

class _StarsBg extends StatelessWidget {
  const _StarsBg();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF050816), Color(0xFF080C20), Color(0xFF050816)])),
      child: Stack(fit: StackFit.expand, children: [IgnorePointer(child: CustomPaint(painter: _StarPaint(), size: Size.infinite))]),
    );
  }
}

class _StarPaint extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(12345);
    final p   = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.25;
      final a = rng.nextDouble() * 0.14 + 0.04;
      p.color = (i % 5 == 0 ? const Color(0xFF88CCFF) : Colors.white).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _MilestoneCard extends StatelessWidget {
  final int    journeyNumber;
  final String journeyTitle;
  final int    xpEarned;
  final int    xpTotal;
  final int    coinsEarned;
  final int    doneCount;
  final int    totalCount;
  final bool   unlocked;

  const _MilestoneCard({
    required this.journeyNumber,
    required this.journeyTitle,
    required this.xpEarned,
    required this.xpTotal,
    required this.coinsEarned,
    required this.doneCount,
    required this.totalCount,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final xpPct = (xpEarned / xpTotal).clamp(0.0, 1.0);
    final lockColor = unlocked ? _kPath : Colors.grey.shade700;
    final lockColorLight = unlocked ? _kPathLight : Colors.grey.shade500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lockColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: lockColor.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: -4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: Journey label + star count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JOURNEY $journeyNumber',
                style: TextStyle(color: lockColorLight, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lockColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lockColor.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.monetization_on_rounded,
                      color: unlocked ? const Color(0xFFFFD700) : Colors.grey,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    // Show actual earned / max possible (10 scenarios × 60 coins each)
                    '$coinsEarned / ${totalCount * 60}',
                    style: TextStyle(
                      color: unlocked ? const Color(0xFFFFD700) : Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Journey title
          Text(
            journeyTitle,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          // ── XP bar row
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                '$xpEarned / $xpTotal XP',
                style: TextStyle(color: lockColorLight, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$doneCount / $totalCount done',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: xpPct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF5B52F0),
              ),
            ),
          ),

          const SizedBox(height: 10),
          // ── Grey hint note — always visible
          Text(
            'Min. $_kMinCoinsForJourney2 coins needed to unlock next journey',
            style: const TextStyle(color: Colors.white30, fontSize: 10.5, fontStyle: FontStyle.italic),
          ),

          // ── Lock indicator (only if locked)
          if (!unlocked) ...
          [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.orangeAccent, size: 13),
                const SizedBox(width: 5),
                Text(
                  'Earn ${_kMinCoinsForJourney2 - coinsEarned > 0 ? _kMinCoinsForJourney2 - coinsEarned : 0} more coins to unlock',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double pct;
  final int totalCoins;
  final GlobalKey? coinKey, profileKey;
  const _Header({required this.pct, required this.totalCoins, this.coinKey, this.profileKey});

  String _formatCoins(int val) {
    String s = val.toString();
    if (s.length <= 3) return s;
    return s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1628).withValues(alpha: 0.95), // Home page surface bluish-violet
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sky Campus Path', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)), Text('20 Scenario Journey', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))])),
          Container(
              key: coinKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5), width: 1.2)),
              child: Row(children: [
                // Simplified Matte Solid Coin
                Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFC107),
                  ),
                  child: Center(
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_formatCoins(totalCoins), style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.4))
              ])),
        ]),
        const SizedBox(height: 10),
        Stack(children: [
          Container(height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(widthFactor: pct, child: Container(height: 5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: const LinearGradient(colors: [_kPath, _kPathLight]), boxShadow: const [BoxShadow(color: Color(0x667835FF), blurRadius: 6, spreadRadius: 1)]))),
          Positioned(right: 0, top: -16, child: Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
      ]),
    );
  }
}

class _BottomCard extends StatelessWidget {
  final _Hub hub;
  final String illoPath;
  final int completed;
  final double progress;
  const _BottomCard({required this.hub, required this.illoPath, required this.completed, required this.progress});
  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 74),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kBorder, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, 4)), BoxShadow(color: _kPath.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, -2))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: hub.glow.withValues(alpha: 0.5), width: 1.5)), child: ClipOval(child: Image.asset(illoPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: hub.dark, child: const Center(child: Text('🌱', style: TextStyle(fontSize: 20))))))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(hub.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$completed / $_kPerHub Levels Completed', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  const SizedBox(height: 8),
                  Stack(children: [
                    Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(2))),
                    if (progress > 0) FractionallySizedBox(widthFactor: progress, child: Container(height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: LinearGradient(colors: [_kPath, hub.glow]), boxShadow: [BoxShadow(color: _kPath.withValues(alpha: 0.5), blurRadius: 6)]))),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatefulWidget {
  final CommuniqLevel level;
  final VoidCallback onStart;
  const _Sheet({required this.level, required this.onStart});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 32;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, pad),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: _kBorder, width: 1.5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 22),
        ScaleTransition(scale: _scale, child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _kPath.withValues(alpha: 0.5), width: 2.5), boxShadow: const [BoxShadow(color: Color(0x447835FF), blurRadius: 28, spreadRadius: 4)]), child: ClipOval(child: Image.asset(widget.level.imageAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kPath, _kPathLight], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Center(child: Text(widget.level.categoryEmoji, style: const TextStyle(fontSize: 34)))))))),
        const SizedBox(height: 14),
        FadeTransition(opacity: _fade, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: _kPathLight.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: _kPathLight.withValues(alpha: 0.3))), child: const Text('+20 XP', style: TextStyle(color: _kPathLight, fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(height: 10),
          Text(widget.level.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(widget.level.scenario, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR CHALLENGE', style: TextStyle(color: _kPathLight, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)), const SizedBox(height: 8), Text(widget.level.responsePrompt, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.6))])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: DecoratedBox(decoration: BoxDecoration(gradient: const LinearGradient(colors: [_kPath, _kPathLight], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x557835FF), blurRadius: 20, spreadRadius: 1)]), child: TextButton(onPressed: widget.onStart, style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Start Scenario', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))),
        ])),
      ]),
    );
  }
}

class _FlyingParticle extends StatefulWidget {
  final String icon;
  final Offset start, end;
  final bool isBig;
  final VoidCallback onComplete;
  const _FlyingParticle({required this.icon, required this.start, required this.end, required this.onComplete, this.isBig = false});
  @override
  State<_FlyingParticle> createState() => _FlyingParticleState();
}

class _FlyingParticleState extends State<_FlyingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim, _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _scale = TweenSequence<double>([TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 20), TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60), TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20)]).animate(_ctrl);
    _ctrl.forward().then((_) => widget.onComplete());
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final pos = Offset.lerp(widget.start, widget.end, _anim.value)!;
        final dy = sin(_anim.value * pi) * -100;
        return Positioned(left: pos.dx - 15, top: pos.dy + dy - 15, child: Transform.scale(scale: _scale.value * (widget.isBig ? 2.5 : 1.0), child: Material(color: Colors.transparent, child: Text(widget.icon, style: const TextStyle(fontSize: 24)))));
      },
    );
  }
}
