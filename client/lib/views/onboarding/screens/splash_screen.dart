import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:communiq/core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _textController;
  late AnimationController _ringController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    // Head for welcome; the router's redirect sends an already-signed-in user
    // straight to /home instead.
    context.go(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackground(glowAnimation: _glowAnimation),
            _OrbitRings(ringController: _ringController, glowAnimation: _glowAnimation),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _MicLottieSection(glowAnimation: _glowAnimation),
                ),
                const SizedBox(height: 52),
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: const _BrandingText(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background radial glow painter ─────────────────────────────────────────

class _SplashBackground extends StatelessWidget {
  final Animation<double> glowAnimation;
  const _SplashBackground({required this.glowAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(intensity: glowAnimation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double intensity;
  const _BackgroundPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.bg,
    );

    final center = Offset(size.width / 2, size.height * 0.42);

    // Deep indigo centre bloom
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5B52F0).withOpacity(0.18 * intensity),
            const Color(0xFF5B52F0).withOpacity(0.06 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(
          Rect.fromCenter(center: center, width: 420, height: 420),
        ),
    );

    // Sky-blue accent top-right
    final accentCenter = Offset(size.width * 0.82, size.height * 0.18);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF38BDF8).withOpacity(0.09 * intensity),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCenter(center: accentCenter, width: 280, height: 280),
        ),
    );

    // Violet hint bottom-left
    final violetCenter = Offset(size.width * 0.15, size.height * 0.78);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.07 * intensity),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCenter(center: violetCenter, width: 240, height: 240),
        ),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.intensity != intensity;
}

// ── Subtle orbit rings ──────────────────────────────────────────────────────

class _OrbitRings extends StatelessWidget {
  final AnimationController ringController;
  final Animation<double> glowAnimation;

  const _OrbitRings({
    required this.ringController,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ringController, glowAnimation]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.42 - 115,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: ringController.value * 2 * 3.14159,
                  child: _DashedRing(
                    radius: 115,
                    color: AppColors.brand
                        .withOpacity(0.10 * glowAnimation.value),
                    dashCount: 6,
                    strokeWidth: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.42 - 145,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -ringController.value * 2 * 3.14159,
                  child: _DashedRing(
                    radius: 145,
                    color: AppColors.brand
                        .withOpacity(0.06 * glowAnimation.value),
                    dashCount: 10,
                    strokeWidth: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashedRing extends StatelessWidget {
  final double radius;
  final Color color;
  final int dashCount;
  final double strokeWidth;

  const _DashedRing({
    required this.radius,
    required this.color,
    required this.dashCount,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: _DashPainter(
          color: color,
          dashCount: dashCount,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;

  const _DashPainter({
    required this.color,
    required this.dashCount,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const dashArc = 3.14159 * 2 / 24;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * 3.14159 * 2 / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        dashArc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Mic Lottie with glow halo ───────────────────────────────────────────────

class _MicLottieSection extends StatelessWidget {
  final Animation<double> glowAnimation;
  const _MicLottieSection({required this.glowAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer diffuse glow
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand
                          .withOpacity(0.22 * glowAnimation.value),
                      blurRadius: 70,
                      spreadRadius: 18,
                    ),
                    BoxShadow(
                      color: AppColors.brand
                          .withOpacity(0.10 * glowAnimation.value),
                      blurRadius: 90,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),

              // Frosted glass circle
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brand.withOpacity(0.14),
                      AppColors.surface.withOpacity(0.55),
                      AppColors.bg.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: AppColors.brand.withOpacity(0.18),
                    width: 1.0,
                  ),
                ),
              ),

              // Inner subtle ring
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brand.withOpacity(0.10),
                    width: 0.5,
                  ),
                ),
              ),

              // Lottie animation
              SizedBox(
                width: 130,
                height: 130,
                child: Lottie.asset(
                  'assets/icons/Mic.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Branding text block ────────────────────────────────────────────────────

class _BrandingText extends StatelessWidget {
  const _BrandingText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFBECCE3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'COMMUNIQ',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 9,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 48,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.brand.withOpacity(0.65),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ELEVATING EVERY INTERACTION',
          style: TextStyle(
            color: AppColors.inkSoft.withOpacity(0.85),
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 3.5,
          ),
        ),
      ],
    );
  }
}
