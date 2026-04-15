import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/models/scenario_model.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_conversation_screen.dart';
import 'package:communiq/views/feedback_page.dart';

class SetupScenarioPage extends StatefulWidget {
  final String? prefilledTitle;
  final String? prefilledScenario;
  final String? prefilledPersona;
  final String? prefilledMood;
  final String? prefilledLevel;

  const SetupScenarioPage({
    super.key,
    this.prefilledTitle,
    this.prefilledScenario,
    this.prefilledPersona,
    this.prefilledMood,
    this.prefilledLevel,
  });

  @override
  State<SetupScenarioPage> createState() => _SetupScenarioPageState();
}

class _SetupScenarioPageState extends State<SetupScenarioPage> {
  // ─────────────────────────────────────────────────────────────────────────
  // State Variables
  // ─────────────────────────────────────────────────────────────────────────

  late TextEditingController _scenarioController;
  late TextEditingController _backstoryController;

  // Core Configuration
  String _selectedMood = 'Neutral';
  String _selectedLevel = 'Medium';
  String _selectedPersona = 'Friendly HR';
  String _selectedRole = 'You as Employee';

  // Secondary Configuration
  String _selectedTraits = 'Logical';

  // Loading State
  bool _isStarting = false;
  String? _resolvedScenarioId;

  // ─────────────────────────────────────────────────────────────────────────
  // Dropdown Options
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> moods = ['Neutral', 'Friendly', 'Aggressive', 'Professional'];
  static const List<String> levels = ['Easy', 'Medium', 'Hard', 'Extreme'];
  static const List<String> personas = ['Friendly HR', 'Strict Manager', 'Angry Client'];
  static const List<String> roles = ['You as Employee', 'You as Manager', 'You as Speaker'];
  static const List<String> traitOptions = ['Logical', 'Emotional', 'Assertive', 'Passive'];

  @override
  void initState() {
    super.initState();
    _scenarioController =
        TextEditingController(text: widget.prefilledScenario ?? '');
    _backstoryController = TextEditingController();

    // Set prefilled values
    if (widget.prefilledMood != null && moods.contains(widget.prefilledMood)) {
      _selectedMood = widget.prefilledMood!;
    }
    if (widget.prefilledLevel != null && levels.contains(widget.prefilledLevel)) {
      _selectedLevel = widget.prefilledLevel!;
    }
    if (widget.prefilledPersona != null &&
        personas.contains(widget.prefilledPersona)) {
      _selectedPersona = widget.prefilledPersona!;
    }

    _resolveScenarioId();
  }

  Future<void> _resolveScenarioId() async {
    try {
      final scenarios = await SessionService.instance.fetchScenarios();
      if (scenarios.isEmpty) return;

      final matched = _findBestScenarioMatch(scenarios);
      setState(() {
        _resolvedScenarioId = matched?.scenarioId ?? scenarios.first.scenarioId;
      });
    } catch (_) {
      // Keep null and surface a clear message when user starts roleplay.
    }
  }

  ScenarioModel? _findBestScenarioMatch(List<ScenarioModel> scenarios) {
    final titleNeedle = (widget.prefilledTitle ?? '').trim().toLowerCase();
    final descNeedle = (widget.prefilledScenario ?? '').trim().toLowerCase();

    for (final s in scenarios) {
      if (titleNeedle.isNotEmpty && s.title.toLowerCase() == titleNeedle) {
        return s;
      }
    }

    for (final s in scenarios) {
      if (descNeedle.isNotEmpty && s.description.toLowerCase() == descNeedle) {
        return s;
      }
    }

    for (final s in scenarios) {
      if (titleNeedle.isNotEmpty && s.title.toLowerCase().contains(titleNeedle)) {
        return s;
      }
      if (descNeedle.isNotEmpty && s.description.toLowerCase().contains(descNeedle)) {
        return s;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool get isScenarioEmpty => _scenarioController.text.trim().isEmpty;

  String _generateSummary() {
    final scenario = _scenarioController.text.trim().isNotEmpty
        ? _scenarioController.text.trim().split('\n').first
        : 'Custom practice';

    return 'You are practicing: $scenario with a $_selectedPersona at $_selectedLevel level in a $_selectedMood tone';
  }

  void _showDropdownModal(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                // Options
                ...options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = option == currentValue;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < options.length - 1 ? 12 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: !isSelected
                              ? AppColors.background
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryLight
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        AppColors.primary.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startRoleplay() async {
    if (isScenarioEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your scenario to continue'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final scenarioId = _resolvedScenarioId;
      if (scenarioId == null || scenarioId.isEmpty) {
        throw Exception('No valid scenario available. Please try again in a moment.');
      }

      final sessionId = await SessionService.instance.startSession(
        scenarioId,
        persona: _selectedPersona,
        tone: _selectedMood,
        languageLevel: _selectedLevel,
      );

      final config = RoleplayConfig(
        scenarioId: scenarioId,
        scenarioTitle: (widget.prefilledTitle?.trim().isNotEmpty ?? false)
            ? widget.prefilledTitle!.trim()
            : _scenarioController.text.trim().split('\n').first,
        scenario: _scenarioController.text.trim(),
        persona: _selectedPersona,
        difficulty: _selectedLevel,
        category: 'Custom Setup',
        tone: _selectedMood,
        timeLimit: 'No limit',
        languageLevel: _selectedLevel,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackPage(
            sessionId: sessionId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───────────────────────────────────────────────────────────
                // 1️⃣ HEADER
                // ───────────────────────────────────────────────────────────
                const SizedBox(height: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Setup Scenario',
                        style: AppTextStyles.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // ───────────────────────────────────────────────────────────
                // 2️⃣ SCENARIO INPUT (PRIMARY SECTION)
                // ───────────────────────────────────────────────────────────
                Text(
                  'Scenario',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _scenarioController.text.isEmpty
                          ? AppColors.border
                          : AppColors.primaryLight.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: _scenarioController.text.isNotEmpty
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: TextField(
                    controller: _scenarioController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(18),
                      hintText: 'Describe your scenario...',
                      hintStyle: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.prefilledScenario != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'You can modify this scenario',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_scenarioController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Required field',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────────
                // 3️⃣ CORE CONFIG SECTION (2x2 GRID)
                // ───────────────────────────────────────────────────────────
                Text(
                  'Configuration',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.75,
                  children: [
                    // Mood
                    _DropdownCard(
                      label: 'Mood',
                      value: _selectedMood,
                      onTap: () => _showDropdownModal(
                        'Select Mood',
                        moods,
                        _selectedMood,
                        (v) => setState(() => _selectedMood = v),
                      ),
                    ),
                    // Level
                    _DropdownCard(
                      label: 'Level',
                      value: _selectedLevel,
                      onTap: () => _showDropdownModal(
                        'Select Level',
                        levels,
                        _selectedLevel,
                        (v) => setState(() => _selectedLevel = v),
                      ),
                    ),
                    // Persona
                    _DropdownCard(
                      label: 'Persona',
                      value: _selectedPersona,
                      onTap: () => _showDropdownModal(
                        'Select Persona',
                        personas,
                        _selectedPersona,
                        (v) => setState(() => _selectedPersona = v),
                      ),
                    ),
                    // Role
                    _DropdownCard(
                      label: 'Role',
                      value: _selectedRole,
                      onTap: () => _showDropdownModal(
                        'Select Role',
                        roles,
                        _selectedRole,
                        (v) => setState(() => _selectedRole = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────────
                // 4️⃣ PERSONALITY TRAITS (SECONDARY SECTION)
                // ───────────────────────────────────────────────────────────
                Text(
                  'Personality Traits',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showDropdownModal(
                    'Select Personality Traits',
                    traitOptions,
                    _selectedTraits,
                    (v) => setState(() => _selectedTraits = v),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedTraits,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.primaryLight,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ───────────────────────────────────────────────────────────
                // 5️⃣ BACKSTORY (OPTIONAL ADVANCED)
                // ───────────────────────────────────────────────────────────
                Row(
                  children: [
                    Text(
                      'Backstory',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(Optional)',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _backstoryController,
                    maxLines: 2,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(18),
                      hintText: 'Add additional context (optional)',
                      hintStyle: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ───────────────────────────────────────────────────────────
                // 6️⃣ SMART SUMMARY (AUTO-GENERATED)
                // ───────────────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primaryLight.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryLight.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _generateSummary(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ───────────────────────────────────────────────────────────
                // 7️⃣ PRIMARY CTA BUTTON
                // ───────────────────────────────────────────────────────────
                GestureDetector(
                  onTap: _isStarting ? null : _startRoleplay,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: _isStarting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.8,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Starting...',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Start Roleplay',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// DROPDOWN CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────

class _DropdownCard extends StatefulWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DropdownCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  State<_DropdownCard> createState() => _DropdownCardState();
}

class _DropdownCardState extends State<_DropdownCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surface.withOpacity(0.8)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primaryLight.withOpacity(0.4)
                  : AppColors.border,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: _isHovered
                        ? AppColors.primaryLight
                        : AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
