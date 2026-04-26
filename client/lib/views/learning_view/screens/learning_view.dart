import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

const _kBg        = Color(0xFF050816);
const _kSurface   = Color(0xFF0F172A);
const _kBorder    = Color(0x1AFFFFFF);
const _kPath      = Color(0xFF7835FF);
const _kPathLight = Color(0xFFAA88FF);

// ── Hub illustration mapping ──────────────────────────────────────────────────
// 12 available illustrations cycled across all 15 hubs + all 150 levels
const _kIllos = [
  'assets/images/scenarios/introduce_yourself.png',
  'assets/images/scenarios/job_interview_v2.png',
  'assets/images/scenarios/negotiation_v2.png',
  'assets/images/scenarios/technical_solving.png',
  'assets/images/scenarios/sales_pitch.png',
  'assets/images/scenarios/complex_concept.png',
  'assets/images/scenarios/difficult_client.png',
  'assets/images/scenarios/gd_ai.png',
  'assets/images/scenarios/salary_negotiation.png',
  'assets/images/scenarios/strengths_weaknesses.png',
  'assets/images/scenarios/why_hire_you.png',
  'assets/images/scenarios/cold_call.png',
];

// Deterministic illustration for a hub index
String _hubIllo(int hubIdx) => _kIllos[hubIdx % _kIllos.length];

// ── Per-hub theme ─────────────────────────────────────────────────────────────
class _Hub {
  final String name;
  final Color  glow; // neon edge + label color
  final Color  dark; // dark tint for side faces
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

const _kPerHub  = 10;
const _kTLevels = 200;

// Floating illustration card dimensions
const _kCW = 165.0; // card width
const _kCH = 115.0; // card height

// Canvas layout
const _kZone   = 240.0; // vertical space per hub
const _kTopPad = 60.0;
const _kBotPad = 220.0;

enum _HS { active, locked, completed }

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class LearningView extends StatefulWidget {
  const LearningView({super.key});
  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView>
    with TickerProviderStateMixin {

  List<CommuniqLevel> _levels  = [];
  Set<int>            _done    = {};
  bool                _loading = true;

  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;
  late final AnimationController _shimCtrl;

  double           _sw = 0, _ch = 0;
  int              _n  = 0;
  final Map<int,Offset> _hubPos  = {};
  final List<Offset>    _pathPts = [];
  final _scroll = ScrollController();

  // ── Init / Dispose ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.45, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _shimCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 3))..repeat();
    _load();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _shimCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final lvls = await LevelService.instance.fetchLevels();
      final p    = await SharedPreferences.getInstance();
      final done = (p.getStringList('completed_level_ids') ?? []).map(int.parse).toSet();
      if (mounted) {
        setState(() { _levels = lvls; _done = done; _loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCur());
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Layout ───────────────────────────────────────────────────────────────

  void _layout(double w) {
    if (_sw == w && _hubPos.isNotEmpty) return;
    _sw = w;
    _n  = 20; // Hardcoded to 20 to show all 200 levels on the path
    _ch = _n * _kZone + _kTopPad + _kBotPad;
    _hubPos.clear();
    _pathPts.clear();
    for (int j = 0; j < _n; j++) {
      final y = _ch - _kBotPad - j * _kZone - _kZone * 0.5;
      // Even hubs left, odd hubs right — matching reference S-curve
      final x = j.isEven ? w * 0.33 : w * 0.67;
      _hubPos[j] = Offset(x, y);
      _pathPts.add(Offset(x, y));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int get _curIdx {
    if (_levels.isEmpty || _n == 0) return 0;
    final id = _curId;
    final mx = _n - 1;
    return ((id - 1) ~/ _kPerHub).clamp(0, mx < 0 ? 0 : mx);
  }

  int get _curId {
    for (final l in _levels) {
      if (!_done.contains(l.id)) return l.id;
    }
    return _levels.isEmpty ? 1 : _levels.last.id;
  }

  bool _isLocked(int j) => j != 0 && _comp(j - 1) < _kPerHub;

  int _comp(int j) {
    final s = j * _kPerHub, e = (s + _kPerHub).clamp(0, _levels.length);
    if (s >= _levels.length) return 0;
    return _levels.sublist(s, e).where((l) => _done.contains(l.id)).length;
  }

  _HS _state(int j) {
    if (_n == 0 || _isLocked(j)) return _HS.locked;
    if (_comp(j) >= _kPerHub) return _HS.completed;
    if (j == _curIdx) return _HS.active;
    return _HS.locked;
  }

  void _scrollToCur() {
    if (!_scroll.hasClients) return;
    final pos = _hubPos[_curIdx];
    if (pos == null) return;
    final vh = _scroll.position.viewportDimension;
    final mx = _scroll.position.maxScrollExtent;
    _scroll.animateTo((pos.dy - vh * 0.55).clamp(0.0, mx),
        duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic);
  }

  // ── Interaction ──────────────────────────────────────────────────────────

  void _tap(int j) {
    if (_isLocked(j)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Complete the previous hub first',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _kBorder)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final s = j * _kPerHub, e = (s + _kPerHub).clamp(0, _levels.length);
    if (s >= _levels.length) return;
    final subs = _levels.sublist(s, e);
    final lvl  = subs.firstWhere((l) => !_done.contains(l.id), orElse: () => subs.last);
    _openSheet(lvl);
  }

  void _openSheet(CommuniqLevel level) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _Sheet(
        level: level,
        onStart: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RoleplaySetupScreen(
              mode: 'prefilled', scenario: level.scenario,
              persona: 'Friendly Mentor', difficulty: 'Medium',
              category: level.category, levelId: level.id,
            ),
          )).then((_) async {
            final p  = await SharedPreferences.getInstance();
            final nd = (p.getStringList('completed_level_ids') ?? []).map(int.parse).toSet();
            if (mounted) setState(() => _done = nd);
          });
        },
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasData = !_loading && _levels.isNotEmpty;
    final cj   = hasData ? _curIdx : 0;
    final comp = hasData ? _comp(cj) : 0;
    final prog = hasData ? (comp / _kPerHub).clamp(0.0, 1.0) : 0.0;
    final pct  = (_kTLevels > 0 ? _done.length / _kTLevels : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _StarsBg()),
          SafeArea(
            bottom: false,
            child: Column(children: [
              _Header(pct: pct),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _kPath))
                    : _buildMap(cj),
              ),
            ]),
          ),
          if (hasData)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomCard(
                hub: _kHubs[cj.clamp(0, _kHubs.length - 1)],
                illoPath: _hubIllo(cj),
                completed: comp,
                progress: prog,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(int activeIdx) {
    return LayoutBuilder(builder: (_, box) {
      _layout(box.maxWidth);
      return SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: _sw, height: _ch,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Glowing S-curve path
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _shimCtrl,
                  builder: (_, __) => RepaintBoundary(
                    child: CustomPaint(
                      painter: _PathPaint(_pathPts, _shimCtrl.value, activeIdx),
                    ),
                  ),
                ),
              ),
              // Hub platforms
              for (int j = 0; j < _n; j++)
                if (_hubPos.containsKey(j)) _buildHub(j),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHub(int j) {
    final center   = _hubPos[j]!;
    final st       = _state(j);
    final def      = _kHubs[j.clamp(0, _kHubs.length - 1)];
    final illo     = _hubIllo(j);
    final isLeft   = j.isEven;
    final isActive = st == _HS.active;
    final isLocked = st == _HS.locked;
    final isDone   = st == _HS.completed;

    return Positioned(
      left: center.dx - _kCW / 2,
      top:  center.dy - _kCH / 2 - 22, // room for label above
      child: GestureDetector(
        onTap: () => _tap(j),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) {
            final gv = isActive ? _glowAnim.value : (isLocked ? 0.0 : 0.45);
            return SizedBox(
              width: _kCW,
              child: Column(
                crossAxisAlignment:
                    isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hub name label
                  Padding(
                    padding: EdgeInsets.only(
                        left: isLeft ? 4 : 0, right: isLeft ? 0 : 4),
                    child: Opacity(
                      opacity: isLocked ? 0.35 : 1.0,
                      child: Text(def.name,
                        style: TextStyle(
                          color: isActive ? def.glow : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: isActive
                              ? [Shadow(
                                  color: def.glow.withValues(alpha: 0.8),
                                  blurRadius: 12)]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Floating illustration card (NO box)
                  _HubCard(
                    illoPath: illo,
                    glow: def.glow,
                    isActive: isActive,
                    isLocked: isLocked,
                    isDone: isDone,
                    glowVal: gv,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HUB CARD — floating illustration card, no box geometry
// ═══════════════════════════════════════════════════════════════════════════════

class _HubCard extends StatelessWidget {
  final String illoPath;
  final Color  glow;
  final bool   isActive, isLocked, isDone;
  final double glowVal;

  const _HubCard({
    required this.illoPath,
    required this.glow,
    required this.isActive, required this.isLocked, required this.isDone,
    required this.glowVal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kCW, height: _kCH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [

          // ── Soft radial glow beneath illustration (active/completed only) ──
          if (!isLocked && (isActive || glowVal > 0.2))
            Positioned(
              top: _kCH * 0.2, left: _kCW * 0.1,
              child: Container(
                width: _kCW * 0.8, height: _kCH * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(
                          alpha: glowVal * (isActive ? 0.45 : 0.15)),
                      blurRadius: isActive ? 40 : 18,
                      spreadRadius: isActive ? 12 : 4,
                    ),
                  ],
                ),
              ),
            ),

          // ── Raw illustration — no box, no border, no clip ──────────────────
          // The illustration PNGs have dark backgrounds that normally look like squares.
          // By applying a radial gradient mask, we softly fade the harsh edges
          // into 100% transparency, making the characters seamlessly float on the starfield!
          Opacity(
            opacity: isLocked ? 0.35 : 1.0,
            child: ShaderMask(
              shaderCallback: (Rect bounds) => RadialGradient(
                colors: [Colors.white, Colors.white.withValues(alpha: 0.15), Colors.transparent],
                stops: const [0.45, 0.85, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                illoPath,
                width: _kCW, height: _kCH,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_rounded,
                  color: glow.withValues(alpha: 0.4), size: 48,
                ),
              ),
            ),
          ),

          // ── Lock icon overlay ──────────────────────────────────────────────
          if (isLocked)
            const Icon(Icons.lock_rounded, color: Colors.white38, size: 30),

          // ── Completed badge ────────────────────────────────────────────────
          if (isDone)
            Positioned(
              top: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.green),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 13),
              ),
            ),
        ],
      ),
    );
  }
}




// ═══════════════════════════════════════════════════════════════════════════════
// GLOWING S-CURVE PATH

// ═══════════════════════════════════════════════════════════════════════════════

class _PathPaint extends CustomPainter {
  final List<Offset> pts;
  final double shimmer;
  final int activeIdx;
  const _PathPaint(this.pts, this.shimmer, this.activeIdx);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final activePath = _buildPath(0, activeIdx);
    final futurePath = _buildPath(activeIdx, pts.length - 1);

    // Dim future path
    if (futurePath != null) {
      canvas.drawPath(futurePath, Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round);
    }

    // Glowing active path
    if (activePath != null) {
      // Wide outer halo
      canvas.drawPath(activePath, Paint()
        ..color = _kPath.withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke..strokeWidth = 32
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
        ..strokeCap = StrokeCap.round);

      // Mid glow
      canvas.drawPath(activePath, Paint()
        ..color = _kPath.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..strokeCap = StrokeCap.round);

      // Bright core
      canvas.drawPath(activePath, Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [_kPath, _kPathLight, const Color(0xFF00CCFF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round);

      // Moving shimmer bead over the active portion
      final ms = activePath.computeMetrics().toList();
      if (ms.isNotEmpty) {
        final pm = ms.first;
        final len = pm.length;
        const blen = 90.0;
        final s0 = (shimmer * len) % len;
        final s1 = (s0 + blen).clamp(0.0, len);
        if (s1 > s0) {
          canvas.drawPath(pm.extractPath(s0, s1), Paint()
            ..color = Colors.white.withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke..strokeWidth = 5.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
      }
    }
  }

  Path? _buildPath(int startIdx, int endIdx) {
    if (startIdx >= endIdx || startIdx >= pts.length - 1) return null;
    final p = Path();
    p.moveTo(pts[startIdx].dx, pts[startIdx].dy);
    for (int i = startIdx; i < endIdx && i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final my = (a.dy + b.dy) / 2;
      p.cubicTo(a.dx, my, b.dx, my, b.dx, b.dy);
    }
    return p;
  }

  @override
  bool shouldRepaint(_PathPaint old) => old.shimmer != shimmer || old.activeIdx != activeIdx;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPACE BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════════

class _StarsBg extends StatelessWidget {
  const _StarsBg();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF050816), Color(0xFF080C20), Color(0xFF050816)],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(
          child: CustomPaint(painter: _StarPaint(), size: Size.infinite),
        ),
      ]),
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
      p.color = (i % 5 == 0
          ? const Color(0xFF88CCFF)
          : Colors.white).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final double pct;
  const _Header({required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg.withValues(alpha: 0.92),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _kSurface, border: Border.all(color: _kBorder)),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white70, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sky Campus Path', style: TextStyle(
                    color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                Text('75% Complete', style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 12)),
              ]),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _kSurface, border: Border.all(color: _kBorder)),
              child: const Icon(Icons.person_rounded, color: Colors.white54, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          Stack(children: [
            Container(height: 5,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(colors: [_kPath, _kPathLight]),
                  boxShadow: const [
                    BoxShadow(color: Color(0x667835FF), blurRadius: 6, spreadRadius: 1)
                  ],
                ),
              ),
            ),
            Positioned(right: 0, top: -16,
              child: Text('${(pct * 100).round()}%', style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM HUB CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _BottomCard extends StatelessWidget {
  final _Hub   hub;
  final String illoPath;
  final int    completed;
  final double progress;

  const _BottomCard({
    required this.hub, required this.illoPath,
    required this.completed, required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, botPad + 74),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24, offset: const Offset(0, 4)),
          BoxShadow(color: _kPath.withValues(alpha: 0.08),
              blurRadius: 18, offset: const Offset(0, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              // Circular illustration thumbnail
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: hub.glow.withValues(alpha: 0.5), width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(illoPath, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: hub.dark,
                      child: Center(child: Text('🌱',
                          style: const TextStyle(fontSize: 20)))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hub.name,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$completed / $_kPerHub Levels Completed',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    const SizedBox(height: 8),
                    Stack(children: [
                      Container(height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(2))),
                      if (progress > 0)
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                  colors: [_kPath, hub.glow]),
                              boxShadow: [BoxShadow(
                                  color: _kPath.withValues(alpha: 0.5),
                                  blurRadius: 6)],
                            ),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _Sheet extends StatefulWidget {
  final CommuniqLevel level;
  final VoidCallback  onStart;
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
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 480));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 32;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, pad),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 44, height: 4,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 22),
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 92, height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: _kPath.withValues(alpha: 0.5), width: 2.5),
                boxShadow: const [BoxShadow(
                    color: Color(0x447835FF), blurRadius: 28, spreadRadius: 4)]),
            child: ClipOval(
              child: Image.asset(widget.level.imageAsset, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(
                      colors: [_kPath, _kPathLight],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Center(child: Text(widget.level.categoryEmoji,
                      style: const TextStyle(fontSize: 34))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeTransition(opacity: _fade, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: _kPathLight.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPathLight.withValues(alpha: 0.3))),
            child: const Text('+20 XP', style: TextStyle(
                color: _kPathLight, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Text(widget.level.title, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(widget.level.scenario, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOUR CHALLENGE', style: TextStyle(
                  color: _kPathLight, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1.4)),
              const SizedBox(height: 8),
              Text(widget.level.prompt, style: const TextStyle(
                  color: Color(0xFFCBD5E1), fontSize: 13, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kPath, _kPathLight],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(
                    color: Color(0x557835FF), blurRadius: 20, spreadRadius: 1)],
              ),
              child: TextButton(
                onPressed: widget.onStart,
                style: TextButton.styleFrom(shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
                child: const Text('Start Scenario', style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}
