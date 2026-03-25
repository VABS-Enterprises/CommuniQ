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

  bool _startingSession = false;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<String> _categories = ['Assertiveness', 'Leadership', 'Negotiation', 'General'];
  final List<String> _tones = ['Friendly', 'Strict', 'Neutral'];
  final List<String> _timeLimits = ['60 sec', '2 min', 'No limit'];
  final List<String> _languageLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();

    _selectedPersonaId = _defaultPersonas
        .firstWhere(
          (p) => p.name == (widget.persona ?? 'Strict Boss'),
          orElse: () => _defaultPersonas.first,
        )
        .id;
    _selectedDifficulty = widget.difficulty ?? 'Medium';
    _selectedCategory = widget.category ?? 'General';
    _selectedTone = 'Neutral';
    _selectedTimeLimit = '60 sec';
    _selectedLanguageLevel = 'Intermediate';

    _personasList = List.from(_defaultPersonas);
    _loadPersonas();
    _fetchScenarios();
  }

  Future<void> _fetchScenarios() async {
    setState(() {
      _loadingScenarios = true;
      _scenarioError = null;
    });
    try {
      final scenarios = await SessionService.instance.fetchScenarios();
      ScenarioModel? autoSelected;
      if (scenarios.isNotEmpty) {
        if (widget.mode == 'prefilled' && widget.scenario != null) {
          final prefillLower = widget.scenario!.toLowerCase();
          autoSelected = scenarios.firstWhere(
            (s) => s.title.toLowerCase().contains(prefillLower),
            orElse: () => scenarios.first,
          );
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
    if (!mounted) return;
    setState(() {
      _personasList = [..._defaultPersonas, ...customPersonas];
      if (!_personasList.any((p) => p.id == _selectedPersonaId)) {
        _selectedPersonaId = _defaultPersonas.first.id;
      }
    });
  }

  Future<void> _startRoleplay() async {
    if (_selectedScenario == null) {
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

    try {
      final sessionId = await SessionService.instance.startSession(
        _selectedScenario!.scenarioId,
        persona: selectedPersona.name,
        tone: _selectedTone,
        languageLevel: _selectedLanguageLevel,
      );

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Session Setup',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _loadingScenarios 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 32),
                _buildSectionTitle('AI Persona'),
                const SizedBox(height: 16),
                _buildSimplePersonaList(),
                const SizedBox(height: 32),
                _buildSectionTitle('Advanced Options'),
                const SizedBox(height: 16),
                _buildAdvancedSettings(),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(
            left: 24, right: 24, bottom: 24,
            child: _startingSession
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : GradientButton(
                    text: 'Join Conversation',
                    width: double.infinity,
                    onPressed: _startRoleplay,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDifficulty.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedScenario?.title ?? widget.scenario ?? 'Custom Training',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedScenario?.description ?? 'Practice real-world communication skills in this guided scenario.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSimplePersonaList() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _personasList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final persona = _personasList[index];
          final isSelected = _selectedPersonaId == persona.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedPersonaId = persona.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 110,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primaryLight : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getIconForPersona(persona.name),
                    color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    persona.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsRow('Tone', _selectedTone, _tones, (v) => setState(() => _selectedTone = v!)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _buildSettingsRow('Language', _selectedLanguageLevel, _languageLevels, (v) => setState(() => _selectedLanguageLevel = v!)),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          onChanged: onChanged,
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        ),
      ],
    );
  }

  IconData _getIconForPersona(String name) {
    if (name.contains('Boss')) return Icons.badge_outlined;
    if (name.contains('Client')) return Icons.person_search_outlined;
    if (name.contains('Mentor')) return Icons.psychology_outlined;
    return Icons.face_outlined;
  }
}
