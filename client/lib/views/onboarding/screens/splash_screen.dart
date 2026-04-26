import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _flapController;
  late AnimationController _ringController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // High frequency flap for the entire image
    _flapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.5, end: 1.05)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 70),
      TweenSequenceItem(
          tween: Tween(begin: 1.05, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
    ]).animate(_entranceController);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuart)),
    );

    _startApp();
  }

  Future<void> _startApp() async {
    await _entranceController.forward();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGuard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _flapController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double logoSize = 250.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.background,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // HUD Rings (Subtle Background)
            FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _ringController.value * 2 * math.pi,
                        child: _CircularHUD(
                          radius: 130,
                          color: const Color(0xFF22D3EE).withOpacity(0.1),
                          dashCount: 4,
                          strokeWidth: 1,
                        ),
                      ),
                      Transform.rotate(
                        angle: -_ringController.value * 2 * math.pi,
                        child: _CircularHUD(
                          radius: 150,
                          color: const Color(0xFF22D3EE).withOpacity(0.05),
                          dashCount: 8,
                          strokeWidth: 0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SINGLE UNIFIED LOGO
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: AnimatedBuilder(
                        animation: _flapController,
                        builder: (context, child) {
                          // 3D Perspective Flap on the entire image
                          final flapValue = _flapController.value;
                          final matrix = Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..scale(1.0 + (flapValue * 0.06),
                                1.0 - (flapValue * 0.02));

                          return ClipOval(
                            child: Transform(
                              transform: matrix,
                              alignment: Alignment.center,
                              child: Hero(
                                tag: 'app_logo',
                                child: Image.asset(
                                  'assets/images/hummingbird.png',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Text(
                  'COMMUNIQ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                    shadows: [
                      Shadow(
                        color: Colors.cyanAccent.withOpacity(0.15),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 1,
                  color: const Color(0xFF22D3EE).withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'ELEVATING EVERY INTERACTION',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 4,
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

class _CircularHUD extends StatelessWidget {
  final double radius;
  final Color color;
  final int dashCount;
  final double strokeWidth;

  const _CircularHUD({
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
        painter: _HUDPainter(
          color: color,
          dashCount: dashCount,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _HUDPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;

  _HUDPainter({
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
    final radius = size.width / 2;

    const dashArc = 2 * math.pi / 24;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * 2 * math.pi / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashArc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
