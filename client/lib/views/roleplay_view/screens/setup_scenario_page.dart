import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/routes/app_router.dart' show ConversationArgs;
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
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
      // Must go through go_router: this screen is a page-based route, so an
      // imperative pushReplacement throws "A page-based route cannot be
      // completed using imperative api" — and by this point the session has
      // already been created on the server, so the user loses it.
      context.pushReplacement(
        AppRoutes.roleplayConversation,
        extra: ConversationArgs(config: config, sessionId: sessionId),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Option picker
  // ─────────────────────────────────────────────────────────────────────────

  void _showPicker(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
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
          AppSpacing.s24 + MediaQuery.of(sheetContext).padding.bottom,
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
            Text(title, style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.s16),
            for (final option in options)
              _PickerRow(
                label: option,
                selected: option == current,
                onTap: () {
                  onSelect(option);
                  // The sheet is its own imperative route, so it pops with its
                  // own context — not the page's.
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 4,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.s4,
                    AppSpacing.page,
                    AppSpacing.s24,
                  ),
                  children: [
                    FadeInUp(child: _scenarioCard()),
                    const SizedBox(height: AppSpacing.section),
                    FadeInUp(
                      delay: AppMotion.staggerFor(1),
                      child: const SectionHeader(
                        eyebrow: 'WHO YOU PRACTISE WITH',
                        title: 'The other person',
                      ),
                    ),
                    FadeInUp(
                      delay: AppMotion.staggerFor(2),
                      child: _configList(),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    FadeInUp(
                      delay: AppMotion.staggerFor(3),
                      child: const SectionHeader(
                        eyebrow: 'HOW THEY BEHAVE',
                        title: 'Personality',
                      ),
                    ),
                    FadeInUp(
                      delay: AppMotion.staggerFor(4),
                      child: _traitChips(),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    FadeInUp(
                      delay: AppMotion.staggerFor(5),
                      child: _backstoryCard(),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    FadeInUp(
                      delay: AppMotion.staggerFor(6),
                      child: _summaryCard(),
                    ),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s8,
        AppSpacing.page,
        AppSpacing.s12,
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Back',
            onTap: () => context.pop(),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SET THE SCENE', style: AppTextStyles.eyebrow),
                const SizedBox(height: 2),
                Text('Before you speak', style: AppTextStyles.displaySmall),
              ],
            ),
          ),
          const Mascot(mood: MascotMood.thinking, size: 52),
        ],
      ),
    );
  }

  // ── The scenario itself ───────────────────────────────────────────────────

  Widget _scenarioCard() {
    final preset = _selectedPreset;
    if (_mode == _Mode.preset && preset != null) {
      return ChunkyCard(
        accent: AppColors.brand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon: preset.icon, color: AppColors.brand, size: 46),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset.title, style: AppTextStyles.titleLarge),
                      const SizedBox(height: 2),
                      Text(preset.subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s14),
            // A preset is a starting point, not a cage — swapping to a custom
            // scenario keeps whatever configuration is already chosen.
            GestureDetector(
              onTap: () => setState(() {
                _mode = _Mode.custom;
                _selectedPreset = null;
              }),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded,
                      size: 15, color: AppColors.brand),
                  const SizedBox(width: 6),
                  Text(
                    'Write my own scenario instead',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.brand),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ChunkyCard(
      accent: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                  icon: Icons.tune_rounded, color: AppColors.brand, size: 46),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Your scenario', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text('Describe the conversation you want to practise',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSunk,
              borderRadius: AppRadius.chipRadius,
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            child: TextField(
              controller: _scenarioController,
              maxLines: 4,
              minLines: 3,
              style: AppTextStyles.bodyLarge,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText:
                    'e.g. Asking my manager for a raise after a strong quarter',
                hintStyle:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.inkSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Configuration ─────────────────────────────────────────────────────────

  Widget _configList() {
    return Column(
      children: [
        _ConfigRow(
          icon: Icons.person_rounded,
          label: 'AI persona',
          value: _persona,
          onTap: () => _showPicker('AI persona', _personas, _persona,
              (v) => setState(() => _persona = v)),
        ),
        _ConfigRow(
          icon: Icons.graphic_eq_rounded,
          label: 'Tone',
          value: _tone,
          onTap: () => _showPicker(
              'Tone', _tones, _tone, (v) => setState(() => _tone = v)),
        ),
        _ConfigRow(
          icon: Icons.speed_rounded,
          label: 'Difficulty',
          value: _level,
          onTap: () => _showPicker(
              'Difficulty', _levels, _level, (v) => setState(() => _level = v)),
        ),
        _ConfigRow(
          icon: Icons.badge_rounded,
          label: 'Your role',
          value: _role,
          onTap: () => _showPicker(
              'Your role', _roles, _role, (v) => setState(() => _role = v)),
        ),
      ],
    );
  }

  Widget _traitChips() {
    return Wrap(
      spacing: AppSpacing.s10,
      runSpacing: AppSpacing.s10,
      children: [
        for (final trait in _traitOptions)
          _TraitChip(
            label: trait,
            selected: _traits == trait,
            onTap: () => setState(() => _traits = trait),
          ),
      ],
    );
  }

  // ── Backstory ─────────────────────────────────────────────────────────────

  Widget _backstoryCard() {
    return ChunkyCard(
      fill: AppColors.surfaceAlt,
      accent: AppColors.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BACKSTORY',
                  style:
                      AppTextStyles.eyebrow.copyWith(color: AppColors.sunDark)),
              const SizedBox(width: AppSpacing.s6),
              Text('optional',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Anything the AI should already know about you or the situation.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _backstoryController,
            maxLines: 3,
            minLines: 2,
            style: AppTextStyles.bodyMedium,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              hintText: "e.g. I've been in this role for three years",
              hintStyle:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft),
              border: OutlineInputBorder(
                borderRadius: AppRadius.chipRadius,
                borderSide: const BorderSide(color: AppColors.outline, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.chipRadius,
                borderSide: const BorderSide(color: AppColors.outline, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.chipRadius,
                borderSide: const BorderSide(color: AppColors.brand, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Widget _summaryCard() {
    return ChunkyCard(
      fill: AppColors.brandSoft,
      borderColor: AppColors.brand,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Mascot(mood: MascotMood.proud, size: 46, animate: false),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HERE IS THE PLAN',
                    style: AppTextStyles.eyebrow
                        .copyWith(color: AppColors.brandDark)),
                const SizedBox(height: AppSpacing.s6),
                Text(_generateSummary(),
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _footer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s12,
        AppSpacing.page,
        AppSpacing.s12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canStart) ...[
              Text(
                'Describe your scenario to continue',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            ChunkyButton(
              label: 'Start roleplay',
              icon: Icons.mic_rounded,
              expand: true,
              loading: _isStarting,
              onPressed: _canStart && !_isStarting ? _startRoleplay : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

/// One tappable configuration row: icon, what it sets, and what it is set to.
///
/// Replaces a 2x2 grid of cards that showed a small label above a large value.
/// A vertical list reads in one pass and leaves room for the value to be a full
/// phrase — "You as Candidate" was being squeezed into half the screen width.
class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.item),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          IconTile(icon: icon, color: AppColors.brand, size: 40),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.titleMedium),
              ],
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              color: AppColors.inkSoft, size: 22),
        ],
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.ease,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : AppColors.surface,
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.outline,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: selected ? AppColors.inkOnDark : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      selected: selected,
      accent: AppColors.brand,
      margin: const EdgeInsets.only(bottom: AppSpacing.item),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s14,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.titleMedium)),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.brand, size: 22),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}
