import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/models/persona_model.dart';
import 'package:communiq/models/scenario_model.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_conversation_screen.dart';

class RoleplaySetupScreen extends StatefulWidget {
  final String mode; // 'custom' or 'prefilled'
  final String? scenario;
  final String? persona;
  final String? difficulty;
  final String? category;

  const RoleplaySetupScreen({
    super.key,
    required this.mode,
    this.scenario,
    this.persona,
    this.difficulty,
    this.category,
  });

  @override
  State<RoleplaySetupScreen> createState() => _RoleplaySetupScreenState();
}

class _RoleplaySetupScreenState extends State<RoleplaySetupScreen>
    with SingleTickerProviderStateMixin {
  // ─── Scenario selection ────────────────────────────────────────────────────
  List<ScenarioModel> _scenarios = [];
  ScenarioModel? _selectedScenario;
  bool _loadingScenarios = true;
  String? _scenarioError;

  // ─── Persona ───────────────────────────────────────────────────────────────
  late String _selectedPersonaId;
  late List<PersonaModel> _personasList;

  final List<PersonaModel> _defaultPersonas = [
    PersonaModel(id: 'default_1', name: 'Strict Boss', description: 'High expectations and minimal patience.', isCustom: false),
    PersonaModel(id: 'default_2', name: 'Angry Client', description: 'Frustrated and emotionally charged.', isCustom: false),
    PersonaModel(id: 'default_3', name: 'Friendly Mentor', description: 'Supportive, guiding, and encouraging.', isCustom: false),
  ];

  // ─── Other config ──────────────────────────────────────────────────────────
  late String _selectedDifficulty;
  late String _selectedCategory;
  late String _selectedTone;
  late String _selectedTimeLimit;
  late String _selectedLanguageLevel;

  bool _isAdvancedExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconTurns;

  bool _startingSession = false;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Nightmare'];
  final List<String> _categories = ['Assertiveness', 'Leadership', 'Negotiation', 'General'];
  final List<String> _tones = ['Friendly', 'Strict', 'Neutral'];
  final List<String> _timeLimits = ['30 sec', '60 sec', '2 min', 'No limit'];
  final List<String> _languageLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();

    debugPrint('');
    debugPrint('🎭 [RoleplaySetup] ── Screen opened ──────────────────');
    debugPrint('🎭 [RoleplaySetup] mode=${widget.mode}'
        '${widget.scenario != null ? ", scenario=${widget.scenario}" : ""}'
        '${widget.persona != null ? ", persona=${widget.persona}" : ""}'
        '${widget.difficulty != null ? ", difficulty=${widget.difficulty}" : ""}'
        '${widget.category != null ? ", category=${widget.category}" : ""}');

    // Default to the first default persona's ID; if widget.persona (name) is
    // provided, find the matching ID — fall back to first default if not found.
    _selectedPersonaId = _defaultPersonas
        .firstWhere(
          (p) => p.name == (widget.persona ?? 'Strict Boss'),
          orElse: () => _defaultPersonas.first,
        )
        .id;
    _selectedDifficulty = widget.difficulty ?? 'Medium';
    _selectedCategory = widget.category ?? 'Assertiveness';
    _selectedTone = 'Neutral';
    _selectedTimeLimit = '60 sec';
    _selectedLanguageLevel = 'Intermediate';

    debugPrint('🎭 [RoleplaySetup] Defaults — difficulty=$_selectedDifficulty, '
        'category=$_selectedCategory, tone=$_selectedTone');

    // Auto-expand "Customize more" accordion when a category is pre-selected
    // from the CategoriesSection on the hub screen.
    _isAdvancedExpanded = widget.category != null;

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 250), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_animationController);

    if (_isAdvancedExpanded) _animationController.forward();

    _personasList = List.from(_defaultPersonas);
    _loadPersonas();
    _fetchScenarios();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _fetchScenarios() async {
    debugPrint('🔍 [RoleplaySetup] Fetching scenarios from server...');
    setState(() {
      _loadingScenarios = true;
      _scenarioError = null;
    });
    try {
      final scenarios = await SessionService.instance.fetchScenarios();
      debugPrint('✅ [RoleplaySetup] Loaded ${scenarios.length} scenario(s)');
      if (scenarios.isNotEmpty) {
        debugPrint('   Available: ${scenarios.map((s) => s.title).join(", ")}');
      }
      ScenarioModel? autoSelected;
      if (scenarios.isNotEmpty) {
        if (widget.mode == 'prefilled' && widget.scenario != null) {
          final prefillLower = widget.scenario!.toLowerCase();
          autoSelected = scenarios.firstWhere(
            (s) => s.title.toLowerCase().contains(prefillLower),
            orElse: () => scenarios.first,
          );
          debugPrint('🎭 [RoleplaySetup] Prefill match: "${autoSelected.title}"');
        } else {
          autoSelected = scenarios.first;
        }
      }
      setState(() {
        _scenarios = scenarios;
        _selectedScenario = autoSelected;
        _loadingScenarios = false;
      });
    } catch (e) {
      debugPrint('❌ [RoleplaySetup] _fetchScenarios failed: $e');
      if (!mounted) return;
      setState(() {
        _scenarioError = 'Could not load scenarios. Please check your connection.';
        _loadingScenarios = false;
      });
    }
  }

  Future<void> _loadPersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final customPersonasJson = prefs.getStringList('custom_personas') ?? [];
    final customPersonas =
        customPersonasJson.map((s) => PersonaModel.fromJsonString(s)).toList();
    debugPrint('👤 [RoleplaySetup] Loaded personas — '
        '${_defaultPersonas.length} default, ${customPersonas.length} custom');
    if (!mounted) return;
    setState(() {
      _personasList = [..._defaultPersonas, ...customPersonas];
      if (!_personasList.any((p) => p.id == _selectedPersonaId)) {
        _selectedPersonaId = _defaultPersonas.first.id;
      }
    });
  }

  Future<void> _saveCustomPersona(PersonaModel persona) async {
    debugPrint('👤 [RoleplaySetup] Saving custom persona: "${persona.name}" (${persona.id})');
    final prefs = await SharedPreferences.getInstance();
    final customPersonas = _personasList.where((p) => p.isCustom).toList()
      ..add(persona);
    await prefs.setStringList(
        'custom_personas', customPersonas.map((p) => p.toJsonString()).toList());
    debugPrint('✅ [RoleplaySetup] Custom persona saved — total custom: ${customPersonas.length}');
    if (!mounted) return;
    await _loadPersonas();
  }

  Future<void> _deleteCustomPersona(PersonaModel persona) async {
    debugPrint('🗑  [RoleplaySetup] Deleting custom persona: "${persona.name}" (${persona.id})');
    final prefs = await SharedPreferences.getInstance();
    final customPersonas =
        _personasList.where((p) => p.isCustom && p.id != persona.id).toList();
    await prefs.setStringList(
        'custom_personas', customPersonas.map((p) => p.toJsonString()).toList());
    debugPrint('✅ [RoleplaySetup] Persona deleted — remaining custom: ${customPersonas.length}');
    if (!mounted) return;
    if (_selectedPersonaId == persona.id) {
      setState(() => _selectedPersonaId = _defaultPersonas.first.id);
    }
    await _loadPersonas();
  }

  // ─── Start roleplay ────────────────────────────────────────────────────────

  Future<void> _startRoleplay() async {
    if (_selectedScenario == null) {
      debugPrint('⚠️  [RoleplaySetup] Start pressed but no scenario selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scenario first')),
      );
      return;
    }
    if (_startingSession) return;

    setState(() => _startingSession = true);

    final selectedPersona = _personasList.firstWhere(
      (p) => p.id == _selectedPersonaId,
      orElse: () => _defaultPersonas.first,
    );

    debugPrint('');
    debugPrint('🚀 [RoleplaySetup] Starting session ─────────────────');
    debugPrint('   Scenario:  ${_selectedScenario!.title} (${_selectedScenario!.scenarioId})');
    debugPrint('   Persona:   ${selectedPersona.name}');
    debugPrint('   Difficulty: $_selectedDifficulty');
    debugPrint('   Category:  $_selectedCategory');
    debugPrint('   Tone:      $_selectedTone');
    debugPrint('   Time limit: $_selectedTimeLimit');
    debugPrint('   Lang level: $_selectedLanguageLevel');

    try {
      final sessionId = await SessionService.instance.startSession(
        _selectedScenario!.scenarioId,
        persona: selectedPersona.name,
        tone: _selectedTone,
        languageLevel: _selectedLanguageLevel,
      );

      debugPrint('✅ [RoleplaySetup] Session created — sessionId=$sessionId');
      debugPrint('   Navigating to RoleplayConversationScreen...');
      debugPrint('');

      final config = RoleplayConfig(
        scenarioId: _selectedScenario!.scenarioId,
        scenarioTitle: _selectedScenario!.title,
        scenario: _selectedScenario!.description,
        persona: selectedPersona.name,
        difficulty: _selectedDifficulty,
        category: _selectedCategory,
        tone: _selectedTone,
        timeLimit: _selectedTimeLimit,
        languageLevel: _selectedLanguageLevel,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplayConversationScreen(
            config: config,
            sessionId: sessionId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [RoleplaySetup] Could not start session: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingSession = false);
    }
  }

  // ─── Persona modal ─────────────────────────────────────────────────────────

  void _showAddPersonaModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddPersonaSheet(
        tones: _tones,
        onSave: (persona) async {
          await _saveCustomPersona(persona);
          if (!mounted) return;
          setState(() => _selectedPersonaId = persona.id);
        },
      ),
    );
  }

  void _confirmDeletePersona(PersonaModel persona) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Persona?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete "${persona.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCustomPersona(persona);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _toggleAdvanced() {
    setState(() {
      _isAdvancedExpanded = !_isAdvancedExpanded;
      _isAdvancedExpanded
          ? _animationController.forward()
          : _animationController.reverse();
    });
  }

  IconData _getIconForPersona(String name) {
    if (name.contains('Boss')) return Icons.person;
    if (name.contains('Client')) return Icons.sentiment_dissatisfied;
    if (name.contains('Mentor')) return Icons.support_agent;
    return Icons.face;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Setup Roleplay',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
                left: AppSpacing.s24,
                right: AppSpacing.s24,
                top: AppSpacing.s16,
                bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Select Scenario'),
                const SizedBox(height: AppSpacing.s12),
                _buildScenarioSection(),
                const SizedBox(height: AppSpacing.s32),

                _buildSectionTitle('AI Persona'),
                const SizedBox(height: AppSpacing.s16),
                _buildPersonaList(),
                const SizedBox(height: AppSpacing.s32),

                _buildSectionTitle('Difficulty'),
                const SizedBox(height: AppSpacing.s16),
                _buildDifficultyChips(),
                const SizedBox(height: AppSpacing.s32),

                _buildAdvancedToggle(),
                _buildAdvancedSection(),
              ],
            ),
          ),

          // Sticky bottom button
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s24, vertical: AppSpacing.s24),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _startingSession
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : GradientButton(
                      text: 'Start Roleplay',
                      width: double.infinity,
                      onPressed: _startRoleplay,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Scenario section ──────────────────────────────────────────────────────

  Widget _buildScenarioSection() {
    if (_loadingScenarios) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_scenarioError != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(_scenarioError!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s12),
            TextButton.icon(
              onPressed: _fetchScenarios,
              icon: const Icon(Icons.refresh, color: AppColors.primaryLight),
              label: const Text('Retry', style: TextStyle(color: AppColors.primaryLight)),
            ),
          ],
        ),
      );
    }

    if (_scenarios.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No scenarios available. Please try again later.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _scenarios.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s12),
        itemBuilder: (context, index) {
          final scenario = _scenarios[index];
          final isSelected = _selectedScenario?.scenarioId == scenario.scenarioId;
          return GestureDetector(
            onTap: () => setState(() => _selectedScenario = scenario),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 180,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          scenario.title,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 16),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scenario.typeLabel,
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scenario.difficultyLabel,
                          style: const TextStyle(
                              color: AppColors.primaryLight, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Persona list ──────────────────────────────────────────────────────────

  Widget _buildPersonaList() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _personasList.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s16),
        itemBuilder: (context, index) {
          if (index == _personasList.length) return _buildAddPersonaCard();
          final persona = _personasList[index];
          final isSelected = _selectedPersonaId == persona.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedPersonaId = persona.id),
            onLongPress:
                persona.isCustom ? () => _confirmDeletePersona(persona) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 140,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getIconForPersona(persona.name),
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      size: 32),
                  const SizedBox(height: AppSpacing.s8),
                  Text(persona.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddPersonaCard() {
    return GestureDetector(
      onTap: _showAddPersonaModal,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.primaryLight, size: 32),
            const SizedBox(height: AppSpacing.s8),
            Text('Add',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ─── Difficulty ────────────────────────────────────────────────────────────

  Widget _buildDifficultyChips() {
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s12,
      children: _difficulties.map((d) {
        final isSelected = _selectedDifficulty == d;
        return GestureDetector(
          onTap: () => setState(() => _selectedDifficulty = d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(d,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    )),
          ),
        );
      }).toList(),
    );
  }

  // ─── Advanced section ──────────────────────────────────────────────────────

  Widget _buildAdvancedToggle() {
    return GestureDetector(
      onTap: _toggleAdvanced,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Customize more',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            RotationTransition(
              turns: _iconTurns,
              child: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _isAdvancedExpanded
          ? Container(
              margin: const EdgeInsets.only(top: AppSpacing.s16),
              padding: const EdgeInsets.all(AppSpacing.s24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField('Category', _selectedCategory, _categories,
                      (v) => setState(() => _selectedCategory = v!)),
                  const SizedBox(height: AppSpacing.s24),
                  Text('Conversation Tone',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _tones.map((t) {
                      final isSel = _selectedTone == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSel,
                        onSelected: (v) { if (v) setState(() => _selectedTone = t); },
                        backgroundColor: AppColors.background,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                            color: isSel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                        side: BorderSide(
                            color: isSel ? AppColors.primary : AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  Text('Time Limit (optional)',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _timeLimits.map((tl) {
                      final isSel = _selectedTimeLimit == tl;
                      return ChoiceChip(
                        label: Text(tl),
                        selected: isSel,
                        onSelected: (v) {
                          if (v) setState(() => _selectedTimeLimit = tl);
                        },
                        backgroundColor: AppColors.background,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                            color: isSel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                        side: BorderSide(
                            color: isSel ? AppColors.primary : AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  _buildDropdownField(
                      'Language Level',
                      _selectedLanguageLevel,
                      _languageLevels,
                      (v) => setState(() => _selectedLanguageLevel = v!)),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ─── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold));
  }

  Widget _buildDropdownField(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary),
              onChanged: onChanged,
              items: options
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Add Persona Bottom Sheet ─────────────────────────────────────────────────
// Extracted to a StatefulWidget so its TextEditingControllers are properly
// created in initState and disposed in dispose, eliminating the memory leak
// that would occur if they were created inside a StatefulBuilder callback.

class _AddPersonaSheet extends StatefulWidget {
  final List<String> tones;
  final Future<void> Function(PersonaModel persona) onSave;

  const _AddPersonaSheet({required this.tones, required this.onSave});

  @override
  State<_AddPersonaSheet> createState() => _AddPersonaSheetState();
}

class _AddPersonaSheetState extends State<_AddPersonaSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _tone = 'Neutral';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Persona',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.s24),
            Text('Persona Name',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'e.g., Tough Interviewer'),
            const SizedBox(height: AppSpacing.s16),
            Text('Behavior Description',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            _buildTextField(_descController, 'How should AI behave?',
                maxLines: 3),
            const SizedBox(height: AppSpacing.s16),
            Text('Base Tone',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.tones.map((t) {
                final isSel = _tone == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: isSel,
                  onSelected: (v) {
                    if (v) setState(() => _tone = t);
                  },
                  backgroundColor: AppColors.background,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: isSel
                          ? AppColors.textPrimary
                          : AppColors.textSecondary),
                  side: BorderSide(
                      color: isSel ? AppColors.primary : AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                Expanded(
                  child: GradientButton(
                    text: _saving ? 'Saving...' : 'Save Persona',
                    onPressed: _saving
                        ? () {}
                        : () async {
                            if (_nameController.text.trim().isEmpty) return;
                            setState(() => _saving = true);
                            final newPersona = PersonaModel(
                              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                              name: _nameController.text.trim(),
                              description: _descController.text.trim(),
                              isCustom: true,
                              tone: _tone,
                            );
                            await widget.onSave(newPersona);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
          {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}
