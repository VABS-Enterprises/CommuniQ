import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_feedback_screen.dart';
import 'dart:math' as math;
import 'dart:async';

enum SpeakingState {
  idle,
  listening,
  responding
}

class RoleplayConversationScreen extends StatefulWidget {
  final RoleplayConfig config;

  const RoleplayConversationScreen({
    super.key,
    required this.config,
  });

  @override
  State<RoleplayConversationScreen> createState() => _RoleplayConversationScreenState();
}

class _RoleplayConversationScreenState extends State<RoleplayConversationScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _holdScaleController;
  late Animation<double> _holdScaleAnimation;

  SpeakingState _currentState = SpeakingState.idle;
  String _aiText = "Initializing connection...";
  Timer? _sessionTimer;
  int _secondsElapsed = 0;

  bool _isMuted = false;
  bool _isHolding = false;
  int _totalSpokenSeconds = 0;   // accumulated hold-to-speak time
  DateTime? _holdStartTime;       // when current hold began

  /// End-call is enabled only after user has spoken for >= 10 seconds total
  bool get _canEndCall => _totalSpokenSeconds >= 10;

  @override
  void initState() {
    super.initState();
    // Setup pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Setup waveform animation
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Setup Hold-to-speak button scale
    _holdScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _holdScaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _holdScaleController, curve: Curves.easeInOut),
    );

    _startTimer();

    // Mock initial AI greeting
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _currentState = SpeakingState.responding;
        _aiText = "Hello. Let's get started. Go ahead when you're ready.";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _currentState = SpeakingState.idle;
          _aiText = "Waiting for you...";
        });
      });
    });
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String get _formattedTime {
    int minutes = _secondsElapsed ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    _holdScaleController.dispose();
    super.dispose();
  }

  void _onHoldDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _holdStartTime = DateTime.now();
    setState(() {
      _isHolding = true;
      _currentState = SpeakingState.listening;
      _aiText = "Listening to your response...";
    });
    _holdScaleController.forward();
    _pulseController.duration = const Duration(milliseconds: 800);
    _pulseController.repeat(reverse: true);
  }

  void _onHoldUp(TapUpDetails details) {
    _endHold();
  }

  void _onHoldCancel() {
    _endHold();
  }

  void _endHold() {
    HapticFeedback.mediumImpact();
    // Accumulate spoken seconds from this hold session
    if (_holdStartTime != null) {
      final heldSeconds = DateTime.now().difference(_holdStartTime!).inSeconds;
      _holdStartTime = null;
      setState(() {
        _totalSpokenSeconds += heldSeconds;
        _isHolding = false;
        _currentState = SpeakingState.idle;
        _aiText = "Processing your response...";
      });
    } else {
      setState(() {
        _isHolding = false;
        _currentState = SpeakingState.idle;
        _aiText = "Processing your response...";
      });
    }
    _holdScaleController.reverse();
    _pulseController.duration = const Duration(seconds: 2);
    _pulseController.repeat(reverse: true);
    
    // Simulate AI thinking and replying
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _currentState = SpeakingState.responding;
        _aiText = "I see what you mean. However, we need to look at the bigger picture here.";
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _currentState = SpeakingState.idle;
          _aiText = "Waiting for you...";
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle radial glow centered behind orb
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: MediaQuery.of(context).size.width * 0.5 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrbVisual(),
                      const SizedBox(height: 60),
                      _buildVoiceBars(),
                      const SizedBox(height: 32),
                      _buildAIText(),
                    ],
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                widget.config.persona,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE SESSION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _formattedTime,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbVisual() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double scale = 1.0 + (_pulseController.value * 0.1);
        if (_currentState == SpeakingState.listening) {
          scale = 1.0 + (_pulseController.value * 0.2); // stronger pulse
        }
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple 1
            Transform.scale(
              scale: scale * 1.4,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2 * (1.0 - _pulseController.value)),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Ripple 2
            Transform.scale(
              scale: scale * 1.2,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4 * (1.0 - _pulseController.value)),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Core Orb
            Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      blurRadius: 40 * _pulseController.value,
                      spreadRadius: 5 * _pulseController.value,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVoiceBars() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) {
            // Calculate staggered heights based on state and animation
            double height = 4.0;
            if (_currentState == SpeakingState.responding) {
              final randomOffset = math.sin((_waveformController.value * math.pi * 2) + index);
              height = 8.0 + (16.0 * randomOffset.abs());
            } else if (_currentState == SpeakingState.listening) {
              final randomOffset = math.cos((_waveformController.value * math.pi * 2) - index);
              height = 10.0 + (10.0 * randomOffset.abs());
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAIText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Padding(
        key: ValueKey<String>(_aiText),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Text(
          _aiText,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: AppSpacing.s24, right: AppSpacing.s24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mute Button
          GestureDetector(
            onTap: () {
              setState(() => _isMuted = !_isMuted);
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.volume_up,
                color: _isMuted ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
          
          // Hold to Speak Center Button
          GestureDetector(
            onTapDown: _onHoldDown,
            onTapUp: _onHoldUp,
            onTapCancel: _onHoldCancel,
            child: ScaleTransition(
              scale: _holdScaleAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHolding ? AppColors.primaryDark : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _isHolding ? 'LISTENING' : 'HOLD TO SPEAK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // End Call Button — enabled only after >= 10 s of speaking
          GestureDetector(
            onTap: _canEndCall
                ? () {
                    HapticFeedback.heavyImpact();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoleplayFeedbackScreen(
                          config: FeedbackConfig.demo,
                        ),
                      ),
                    );
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _canEndCall
                    ? const Color(0xFFEF4444)          // red when enabled
                    : AppColors.surface,               // grey surface when locked
                border: Border.all(
                  color: _canEndCall
                      ? const Color(0xFFEF4444)
                      : AppColors.border,
                ),
                boxShadow: _canEndCall
                    ? [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                Icons.call_end_rounded,
                color: _canEndCall ? Colors.white : AppColors.textMuted,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
