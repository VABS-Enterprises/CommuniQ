import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/views/contest_view/contest_state.dart';

class ContestResultPage extends StatefulWidget {
  final int score;
  final int attemptNumber;
  final ContestState contestState;
  final VoidCallback onTryAgain;

  const ContestResultPage({
    super.key,
    required this.score,
    required this.attemptNumber,
    required this.contestState,
    required this.onTryAgain,
  });

  @override
  State<ContestResultPage> createState() => _ContestResultPageState();
}

class _ContestResultPageState extends State<ContestResultPage>
    with TickerProviderStateMixin {
  bool _xpClaimed = false;
  late AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  late int _rank;
  late int _xp;
  late bool _isBest;

  @override
  void initState() {
    super.initState();

    // Record the attempt
    widget.contestState.recordAttempt(widget.score);
    _rank = widget.contestState.rank;
    _xp = 50;
    _isBest = widget.contestState.attempts.last.isBest;

    _scoreCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scoreAnim = Tween<double>(begin: 0, end: widget.score.toDouble())
        .animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scoreCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _feedbackText {
    if (widget.score >= 85) {
      return '"Excellent performance! Your confidence and clarity stood out. Keep this momentum going!"';
    } else if (widget.score >= 70) {
      return '"You improved fluency and tone, but try to reduce long pauses between answers. Work on maintaining energy throughout!"';
    } else {
      return '"Good start! Focus on clarity and speaking in complete sentences. Practice will make a huge difference!"';
    }
  }

  Color get _scoreColor {
    if (widget.score >= 80) return const Color(0xFF22C55E);
    if (widget.score >= 65) return AppColors.primaryLight;
    return const Color(0xFFFBBF24);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ── Header ────────────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Contest Result',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                          'Attempt ${widget.attemptNumber}',
                          style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Score Ring ────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) {
                    final display = _scoreAnim.value.toInt();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _scoreColor.withValues(alpha: 0.07),
                            border: Border.all(
                                color: _scoreColor.withValues(alpha: 0.25),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _scoreColor.withValues(alpha: 0.25),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$display%',
                                style: TextStyle(
                                    color: _scoreColor,
                                    fontSize: 46,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              display >= 80
                                  ? '🔥 Excellent'
                                  : display >= 65
                                      ? '👍 Good'
                                      : '💪 Keep Going',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                            if (_isBest) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF22C55E)
                                          .withValues(alpha: 0.35)),
                                ),
                                child: const Text('🏆 New Best!',
                                    style: TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Stat cards ────────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                              icon: Icons.leaderboard_rounded,
                              label: 'Rank',
                              value: '#$_rank',
                              color: AppColors.primaryLight)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.star_rounded,
                              label: 'XP Earned',
                              value: '+$_xp XP',
                              color: const Color(0xFFFBBF24))),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── AI Feedback ───────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                      boxShadow: AppGlow.cyanGlow(blurRadius: 14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('💡',
                                  style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 10),
                            const Text('AI Coach Feedback',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(_feedbackText,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.6,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Action buttons ────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      // Claim XP
                      if (!_xpClaimed)
                        _ActionButton(
                          label: '⚡ Claim XP (+$_xp XP)',
                          isPrimary: true,
                          onTap: () {
                            setState(() => _xpClaimed = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '+$_xp XP added to your profile!'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Text('✅ XP Claimed!',
                                style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          // Try Again
                          Expanded(
                            child: _ActionButton(
                              label: '🔄 Try Again',
                              isPrimary: false,
                              onTap: () {
                                Navigator.pop(context); // pop result
                                widget.onTryAgain();    // retrigger flow
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Back to Contest
                          Expanded(
                            child: _ActionButton(
                              label: '← Back',
                              isPrimary: false,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label,
      required this.isPrimary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : AppColors.border),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: isPrimary
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
      ),
    );
  }
}
