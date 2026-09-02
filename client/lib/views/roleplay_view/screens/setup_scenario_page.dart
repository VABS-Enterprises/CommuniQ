import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_conversation_screen.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class SetupScenarioPage extends StatefulWidget {
  /// When set the page opens in Preset mode with this preset pre-selected.
  final String? prefilledPresetKey;

  const SetupScenarioPage({
    super.key,
    this.prefilledPresetKey,
  });

  @override
  State<SetupScenarioPage> createState() => _SetupScenarioPageState();
}

enum _Mode { preset, custom }

class _SetupScenarioPageState extends State<SetupScenarioPage> {
  // ── Mode ────────────────────────────────────────────────────────────────────
  late _Mode _mode;
  ScenarioPreset? _selectedPreset;

  // ── Custom scenario text ────────────────────────────────────────────────────
  late final TextEditingController _scenarioController;

  // ── Configuration ───────────────────────────────────────────────────────────
  String _persona = 'Friendly HR';
  String _tone = 'Professional';
  String _level = 'Medium';
  String _role = 'You as Employee';
  String _traits = 'Logical';

  // ── Backstory ───────────────────────────────────────────────────────────────
  late final TextEditingController _backstoryController;

  // ── Loading ─────────────────────────────────────────────────────────────────
  bool _isStarting = false;

  // ── Option lists ────────────────────────────────────────────────────────────
  static const _personas = [
    'Friendly HR',
    'Strict Manager',
    'Angry Client',
    'Friendly Colleague',
    'Interviewer',
  ];
  static const _tones = ['Professional', 'Friendly', 'Neutral', 'Aggressive'];
  static const _levels = ['Easy', 'Medium', 'Hard', 'Extreme'];
  static const _roles = [
    'You as Employee',
    'You as Manager',
    'You as Speaker',
    'You as Candidate',
  ];
  static const _traitOptions = ['Logical', 'Emotional', 'Assertive', 'Passive'];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scenarioController = TextEditingController();
    _backstoryController = TextEditingController();

    if (widget.prefilledPresetKey != null) {
      // An unknown key falls back to a custom scenario rather than silently
      // prefilling the wrong one.
      final preset = presetForKey(widget.prefilledPresetKey);
      if (preset != null) {
        _mode = _Mode.preset;
        _applyPreset(preset);
      } else {
        _mode = _Mode.custom;
      }
    } else {
      _mode = _Mode.custom;
    }
  }

  void _applyPreset(ScenarioPreset preset) {
    _selectedPreset = preset;
    _persona = preset.persona;
    _tone = preset.tone;
    _level = preset.level;
    _role = preset.role;
    _traits = preset.traits;
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Derived state
  // ─────────────────────────────────────────────────────────────────────────

  bool get _canStart {
    if (_mode == _Mode.preset) return _selectedPreset != null;
    return _scenarioController.text.trim().isNotEmpty;
  }

  String _generateSummary() {
    final context = _mode == _Mode.preset
        ? (_selectedPreset?.title ?? 'scenario')
        : (_scenarioController.text.trim().isNotEmpty
            ? _scenarioController.text.trim().split('\n').first
            : 'your scenario');
    return 'Practicing "$context" with a $_persona ($_tone, $_level level). '
        'You play: $_role · AI traits: $_traits';
  }

  String _buildCustomSystemPrompt() {
    final desc = _scenarioController.text.trim();
    return 'You are roleplaying in the following scenario:\n\n'
        '$desc\n\n'
        'Stay fully in character throughout the conversation. '
        'Help the user practice their real-world communication skills in this scenario. '
        'Be realistic but constructive. Do not break character.';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startRoleplay() async {
    if (!_canStart || _isStarting) return;
    setState(() => _isStarting = true);

    final scenarioPrompt = _mode == _Mode.preset
        ? _selectedPreset!.systemPrompt
        : _buildCustomSystemPrompt();

    final scenarioTitle = _mode == _Mode.preset
        ? _selectedPreset!.title
        : _scenarioController.text.trim().split('\n').first;

    final backstory = _backstoryController.text.trim();

    debugPrint('');
    debugPrint('🚀 [SetupScenario] Starting roleplay ──────────────────');
    debugPrint('   mode:      ${_mode.name}');
    debugPrint('   title:     $scenarioTitle');
    debugPrint('   persona:   $_persona  tone: $_tone  level: $_level');
    debugPrint('   role:      $_role  traits: $_traits');
    if (backstory.isNotEmpty) debugPrint('   backstory: $backstory');

    try {
      final sessionId = await SessionService.instance.startSession(
        '',
        scenarioPrompt: scenarioPrompt,
        scenarioTitle: scenarioTitle,
        persona: _persona,
        tone: _tone,
        languageLevel: _level,
        role: _role,
        traits: _traits,
        backstory: backstory.isNotEmpty ? backstory : null,
      );

      debugPrint('✅ [SetupScenario] Session created → $sessionId');

      final config = RoleplayConfig(
        scenarioId: '',
        scenarioTitle: scenarioTitle,
        scenario: _mode == _Mode.preset
            ? _selectedPreset!.subtitle
            : _scenarioController.text.trim(),
        persona: _persona,
        difficulty: _level,
        category: _mode == _Mode.preset
            ? _selectedPreset!.title
            : 'Custom',
        tone: _tone,
        timeLimit: 'No limit',
        languageLevel: _level,
        role: _role,
        traits: _traits,
        backstory: backstory,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplayConversationScreen(
            config: config,
            sessionId: sessionId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [SetupScenario] startSession failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start session: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showPicker(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              ...options.asMap().entries.map((e) {
                final isSelected = e.value == current;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < options.length - 1 ? 12 : 0),
                  child: GestureDetector(
                    onTap: () {
                      onSelect(e.value);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.value,
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
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 28),
              if (_mode == _Mode.custom) ...[
                _buildCustomInput(),
                const SizedBox(height: 32),
              ],
              _buildSectionTitle('Configuration'),
              const SizedBox(height: 16),
              _buildConfigGrid(),
              const SizedBox(height: 28),
              _buildSectionTitle('AI Personality'),
              const SizedBox(height: 12),
              _buildTraitChips(),
              const SizedBox(height: 28),
              _buildBackstoryField(),
              const SizedBox(height: 28),
              _buildSummaryCard(),
              const SizedBox(height: 28),
              _buildStartButton(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section builders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF141D2C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 17),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setup Scenario',
              style: AppTextStyles.headlineSmall.copyWith(
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Configure your practice session',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioImage(String asset) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput() {
    final isEmpty = _scenarioController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Describe Your Scenario'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1520),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEmpty
                  ? AppColors.border
                  : AppColors.primaryLight.withValues(alpha: 0.4),
              width: isEmpty ? 1 : 1.5,
            ),
          ),
          child: TextField(
            controller: _scenarioController,
            onChanged: (_) => setState(() {}),
            maxLines: 5,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(18),
              hintText:
                  'e.g. "I want to practice negotiating my salary with my manager after completing a successful project..."',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            isEmpty
                ? 'Required — describe the conversation you want to practice'
                : '✓ Scenario described',
            style: AppTextStyles.bodySmall.copyWith(
              color: isEmpty ? AppColors.textMuted : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.75,
      children: [
        _ConfigCard(
          label: 'AI Persona',
          value: _persona,
          onTap: () => _showPicker('AI Persona', _personas, _persona,
              (v) => setState(() => _persona = v)),
        ),
        _ConfigCard(
          label: 'Tone',
          value: _tone,
          onTap: () => _showPicker('Conversation Tone', _tones, _tone,
              (v) => setState(() => _tone = v)),
        ),
        _ConfigCard(
          label: 'Level',
          value: _level,
          onTap: () => _showPicker('Difficulty Level', _levels, _level,
              (v) => setState(() => _level = v)),
        ),
        _ConfigCard(
          label: 'Your Role',
          value: _role,
          onTap: () => _showPicker(
              'Your Role', _roles, _role, (v) => setState(() => _role = v)),
        ),
      ],
    );
  }

  Widget _buildTraitChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _traitOptions.map((trait) {
        final isSelected = _traits == trait;
        return GestureDetector(
          onTap: () => setState(() => _traits = trait),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected ? AppColors.primaryLight : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              trait,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackstoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Backstory'),
            const SizedBox(width: 8),
            Text(
              '(Optional)',
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1520),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _backstoryController,
            maxLines: 2,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              hintText:
                  'Extra context for the AI (e.g. "I have 3 years of experience...")',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primaryLight.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.22),
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
          const SizedBox(height: 8),
          Text(
            _generateSummary(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final active = _canStart && !_isStarting;
    return GestureDetector(
      onTap: active ? _startRoleplay : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          boxShadow: null,
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
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Starting...',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : Text(
                  'Start Roleplay',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: active ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Config card widget
// -----------------------------------------------------------------------------

class _ConfigCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ConfigCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.primaryLight, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
