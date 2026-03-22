import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/models/roleplay_config.dart';
import 'package:communiq/models/persona_model.dart';
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

class _RoleplaySetupScreenState extends State<RoleplaySetupScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _scenarioController;
  late String _selectedPersonaName;
  late String _selectedDifficulty;
  late String _selectedCategory;
  late String _selectedTone;
  late String _selectedTimeLimit;
  late String _selectedLanguageLevel;

  bool _isAdvancedExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconTurns;

  List<PersonaModel> _personasList = [];

  final List<PersonaModel> _defaultPersonas = [
    PersonaModel(id: 'default_1', name: 'Strict Boss', description: 'High expectations and minimal patience.', isCustom: false),
    PersonaModel(id: 'default_2', name: 'Angry Client', description: 'Frustrated and emotionally charged.', isCustom: false),
    PersonaModel(id: 'default_3', name: 'Friendly Mentor', description: 'Supportive, guiding, and encouraging.', isCustom: false),
  ];

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Nightmare'];
  final List<String> _categories = ['Assertiveness', 'Leadership', 'Negotiation', 'General'];
  final List<String> _tones = ['Friendly', 'Strict', 'Neutral'];
  final List<String> _timeLimits = ['30 sec', '60 sec', '2 min', 'No limit'];
  final List<String> _languageLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _scenarioController = TextEditingController(text: widget.scenario ?? '');
    _selectedPersonaName = widget.persona ?? 'Strict Boss';
    _selectedDifficulty = widget.difficulty ?? 'Medium';
    _selectedCategory = widget.category ?? 'Assertiveness';
    _selectedTone = 'Neutral';
    _selectedTimeLimit = '60 sec';
    _selectedLanguageLevel = 'Intermediate';

    _animationController = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_animationController);

    _loadPersonas();
  }

  Future<void> _loadPersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final customPersonasJson = prefs.getStringList('custom_personas') ?? [];
    
    final customPersonas = customPersonasJson.map((str) => PersonaModel.fromJsonString(str)).toList();
    
    setState(() {
      _personasList = [..._defaultPersonas, ...customPersonas];
      
      // Ensure the selected persona actually exists in the combined list
      if (!_personasList.any((p) => p.name == _selectedPersonaName)) {
        _selectedPersonaName = _defaultPersonas.first.name;
      }
    });
  }

  Future<void> _saveCustomPersona(PersonaModel persona) async {
    final prefs = await SharedPreferences.getInstance();
    final customPersonas = _personasList.where((p) => p.isCustom).toList();
    customPersonas.add(persona);
    
    await prefs.setStringList(
      'custom_personas',
      customPersonas.map((p) => p.toJsonString()).toList(),
    );
    
    await _loadPersonas();
  }

  Future<void> _deleteCustomPersona(PersonaModel persona) async {
    final prefs = await SharedPreferences.getInstance();
    final customPersonas = _personasList.where((p) => p.isCustom && p.id != persona.id).toList();
    
    await prefs.setStringList(
      'custom_personas',
      customPersonas.map((p) => p.toJsonString()).toList(),
    );
    
    if (_selectedPersonaName == persona.name) {
      _selectedPersonaName = _defaultPersonas.first.name;
    }
    
    await _loadPersonas();
  }

  void _showAddPersonaModal() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String newTone = 'Neutral';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Persona',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    Text('Persona Name', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g., Tough Interviewer',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text('Behavior Description', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'How should AI behave?',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text('Base Tone', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _tones.map((t) {
                        final isSel = newTone == t;
                        return ChoiceChip(
                          label: Text(t),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setModalState(() => newTone = t);
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSel ? AppColors.textPrimary : AppColors.textSecondary),
                          side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.s32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        Expanded(
                          child: GradientButton(
                            text: 'Save Persona',
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;
                              final newId = 'custom_\${DateTime.now().millisecondsSinceEpoch}';
                              final newPersona = PersonaModel(
                                id: newId,
                                name: nameController.text.trim(),
                                description: descController.text.trim(),
                                isCustom: true,
                                tone: newTone,
                              );
                              await _saveCustomPersona(newPersona);
                              setState(() {
                                _selectedPersonaName = newPersona.name;
                              });
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
          },
        );
      },
    );
  }

  void _confirmDeletePersona(PersonaModel persona) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Persona?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Are you sure you want to delete "\${persona.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCustomPersona(persona);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _generateScenario() {
    setState(() {
      _scenarioController.text = "You are requesting a 20% salary increase from your manager after taking on extra team responsibilities.";
    });
  }

  void _startRoleplay() {
    final config = RoleplayConfig(
      scenario: _scenarioController.text,
      persona: _selectedPersonaName,
      difficulty: _selectedDifficulty,
      category: _selectedCategory,
      tone: _selectedTone,
      timeLimit: _selectedTimeLimit,
      languageLevel: _selectedLanguageLevel,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleplayConversationScreen(config: config),
      ),
    );
  }

  void _toggleAdvanced() {
    setState(() {
      _isAdvancedExpanded = !_isAdvancedExpanded;
      if (_isAdvancedExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  IconData _getIconForPersona(String name) {
    if (name.contains('Boss')) return Icons.person;
    if (name.contains('Client')) return Icons.sentiment_dissatisfied;
    if (name.contains('Mentor')) return Icons.support_agent;
    return Icons.face; // Default custom icon
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scenarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Setup Roleplay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.s24,
              right: AppSpacing.s24,
              top: AppSpacing.s16,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Scenario'),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _scenarioController,
                        maxLines: 4,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Describe your situation...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _generateScenario,
                          icon: const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 16),
                          label: Text(
                            'Generate Scenario (AI)',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),
                
                _buildSectionTitle('AI Persona'),
                const SizedBox(height: AppSpacing.s16),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _personasList.length + 1, // +1 for Add card
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s16),
                    itemBuilder: (context, index) {
                      if (index == _personasList.length) {
                        return _buildAddPersonaCard();
                      }
                      
                      final persona = _personasList[index];
                      final isSelected = _selectedPersonaName == persona.name;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPersonaName = persona.name),
                        onLongPress: persona.isCustom ? () => _confirmDeletePersona(persona) : null,
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
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getIconForPersona(persona.name),
                                      color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                                      size: 32,
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      persona.name,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (persona.isCustom && isSelected)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeletePersona(persona),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),
                
                _buildSectionTitle('Difficulty'),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s12,
                  children: _difficulties.map((difficulty) {
                    final isSelected = _selectedDifficulty == difficulty;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDifficulty = difficulty),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          difficulty,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.s32),
                
                GestureDetector(
                  onTap: _toggleAdvanced,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customize more',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        RotationTransition(
                          turns: _iconTurns,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                AnimatedSize(
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
                              _buildDropdownField('Category', _selectedCategory, _categories, (v) => setState(() => _selectedCategory = v!)),
                              const SizedBox(height: AppSpacing.s24),
                              
                              Text('Conversation Tone', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _tones.map((t) {
                                  final isSel = _selectedTone == t;
                                  return ChoiceChip(
                                    label: Text(t),
                                    selected: isSel,
                                    onSelected: (val) { if (val) setState(() => _selectedTone = t); },
                                    backgroundColor: AppColors.background,
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(color: isSel ? AppColors.textPrimary : AppColors.textSecondary),
                                    side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.s24),
                              
                              Text('Time Limit (optional)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _timeLimits.map((tl) {
                                  final isSel = _selectedTimeLimit == tl;
                                  return ChoiceChip(
                                    label: Text(tl),
                                    selected: isSel,
                                    onSelected: (val) { if (val) setState(() => _selectedTimeLimit = tl); },
                                    backgroundColor: AppColors.background,
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(color: isSel ? AppColors.textPrimary : AppColors.textSecondary),
                                    side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.s24),
                              
                              _buildDropdownField('Language Level', _selectedLanguageLevel, _languageLevels, (v) => setState(() => _selectedLanguageLevel = v!)),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s24),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: GradientButton(
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            width: 1.5,
            style: BorderStyle.none, // We simulate dashed physically, or use standard solid if complex. Kept minimal subtle border here.
          ),
        ),
        // Draw subtle border manually or rely on standard themes. Here we rely on a soft colored standard border.
        child: DecoratedBox(
          decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add,
                color: AppColors.primaryLight,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Add',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
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
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              onChanged: onChanged,
              items: options.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
