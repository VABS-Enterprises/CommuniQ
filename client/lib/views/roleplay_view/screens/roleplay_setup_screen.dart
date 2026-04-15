import 'dart:math';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/roleplay_config.dart';
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

class _RoleplaySetupScreenState extends State<RoleplaySetupScreen> {
  late String _setupScenarioTitle;
  late String _setupScenarioDesc;

  // State variables for the control strip
  String _selectedPartner = 'Strict Manager';
  String _selectedLevel = 'Medium';
  String _selectedMode = 'Focused';

  bool _startingSession = false;

  final List<String> _partners = ['Strict Manager', 'Difficult Client', 'Friendly HR'];
  final List<String> _levels = ['Easy', 'Medium', 'Hard', 'Extreme'];
  final List<String> _modes = ['Guided', 'Focused', 'Realistic'];

  @override
  void initState() {
    super.initState();
    _setupScenarioTitle = widget.category ?? 'Custom Scenario';
    _setupScenarioDesc = widget.scenario ?? '';

    if (widget.persona != null && _partners.contains(widget.persona)) {
      _selectedPartner = widget.persona!;
    }
    if (widget.difficulty != null && _levels.contains(widget.difficulty)) {
      _selectedLevel = widget.difficulty!;
    }
  }

  void _openCustomEditor() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _CustomScenarioEditorScreen(initialText: _setupScenarioDesc),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _setupScenarioDesc = result.trim();
      });
    }
  }

  void _showPicker(String title, List<String> options, String currentValue, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ...options.map((option) {
                  final isSelected = option == currentValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
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

  Future<void> _launchRoleplay() async {
    if (_setupScenarioDesc.isEmpty && widget.mode == 'custom') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a scenario first.')),
      );
      return;
    }

    if (_startingSession) return;
    setState(() => _startingSession = true);

    try {
      final sessionId = await SessionService.instance.startSession(
        'custom_${DateTime.now().millisecondsSinceEpoch}',
        persona: _selectedPartner,
        tone: _selectedMode == 'Realistic' ? 'Strict' : (_selectedMode == 'Guided' ? 'Friendly' : 'Neutral'),
        languageLevel: _selectedLevel,
      );

      final config = RoleplayConfig(
        scenarioId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        scenarioTitle: _setupScenarioTitle,
        scenario: _setupScenarioDesc.isNotEmpty ? _setupScenarioDesc : 'Self-guided practice.',
        persona: _selectedPartner,
        difficulty: _selectedLevel,
        category: _setupScenarioTitle,
        tone: _selectedMode,
        timeLimit: 'No limit',
        languageLevel: _selectedLevel,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingSession = false);
    }
  }

  void _quickStart() {
    setState(() {
      _selectedPartner = 'Friendly HR';
      _selectedLevel = 'Medium';
      _selectedMode = 'Focused';
    });
    _launchRoleplay();
  }

  void _surpriseMe() {
    final rand = Random();
    setState(() {
      _selectedPartner = _partners[rand.nextInt(_partners.length)];
      _selectedLevel = _levels[rand.nextInt(_levels.length)];
      _selectedMode = _modes[rand.nextInt(_modes.length)];
    });
    _launchRoleplay();
  }

  String _getDynamicPrompt() {
    if (_setupScenarioTitle.toLowerCase().contains('salary')) return "Why should we offer you a higher salary?";
    if (_setupScenarioTitle.toLowerCase().contains('interview')) return "Tell me about a time you faced a difficult challenge.";
    if (_setupScenarioTitle.toLowerCase().contains('sales') || _setupScenarioTitle.toLowerCase().contains('pitch')) return "What makes your product different from competitors?";
    if (_selectedPartner.contains('Client')) return "I'm not happy with the current delivery timeline.";
    return "How do you want to handle this situation?";
  }

  String _getMicroInsight() {
    if (_selectedLevel == 'Hard' || _selectedLevel == 'Extreme') return "This will test your composure under pressure.";
    if (_selectedMode == 'Guided') return "Focus on your pacing and clarity; suggestions will be provided.";
    return "This will test your confidence and clarity.";
  }

  String _getPartnerEmoji(String partner) {
    if (partner.contains('Strict')) return '👨‍💼';
    if (partner.contains('Client')) return '😡';
    if (partner.contains('Friendly') || partner.contains('HR')) return '🤝';
    return '👤';
  }

  String _getLevelEmoji(String level) {
    if (level == 'Easy') return '🌱';
    if (level == 'Medium') return '😐';
    if (level == 'Hard') return '🔥';
    if (level == 'Extreme') return '🌋';
    return '⭐';
  }

  String _getModeEmoji(String mode) {
    if (mode == 'Guided') return '🧭';
    if (mode == 'Focused') return '🎯';
    if (mode == 'Realistic') return '🎭';
    return '⚙️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Roleplay', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2️⃣ SCENARIO HERO
              if (widget.mode == 'custom')
                GestureDetector(
                  onTap: _openCustomEditor,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Create Your Scenario",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _setupScenarioDesc.isEmpty ? "Tap here to write your custom roleplay prompt." : _setupScenarioDesc,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _setupScenarioDesc.isEmpty ? AppColors.primaryLight : AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      _setupScenarioTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _setupScenarioDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 48),

              // 3️⃣ CONTROL STRIP
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlChip(
                      label: '${_getPartnerEmoji(_selectedPartner)} ${_selectedPartner.split(' ').last}',
                      onTap: () => _showPicker('Select Partner', _partners, _selectedPartner, (v) => setState(() => _selectedPartner = v)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
                    ),
                    _ControlChip(
                      label: '${_getLevelEmoji(_selectedLevel)} $_selectedLevel',
                      onTap: () => _showPicker('Select Level', _levels, _selectedLevel, (v) => setState(() => _selectedLevel = v)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
                    ),
                    _ControlChip(
                      label: '${_getModeEmoji(_selectedMode)} $_selectedMode',
                      onTap: () => _showPicker('Select Mode', _modes, _selectedMode, (v) => setState(() => _selectedMode = v)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 4️⃣ CONVERSATION PROMPT LINE
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '"${_getDynamicPrompt()}"',
                  key: ValueKey('${_getDynamicPrompt()}$_selectedPartner$_selectedLevel$_selectedMode'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 5️⃣ AI MICRO INSIGHT
              Text(
                _getMicroInsight(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 48),

              // 6️⃣ PRIMARY CTA
              GestureDetector(
                onTap: _startingSession ? null : _launchRoleplay,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: _startingSession
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "Start Speaking",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 7️⃣ SECONDARY ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _startingSession ? null : _quickStart,
                    icon: const Text('⚡', style: TextStyle(fontSize: 16)),
                    label: const Text(
                      'Quick Start',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _startingSession ? null : _surpriseMe,
                    icon: const Text('🎲', style: TextStyle(fontSize: 16)),
                    label: const Text(
                      'Surprise Me',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ControlChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CustomScenarioEditorScreen extends StatefulWidget {
  final String initialText;

  const _CustomScenarioEditorScreen({required this.initialText});

  @override
  State<_CustomScenarioEditorScreen> createState() => _CustomScenarioEditorScreenState();
}

class _CustomScenarioEditorScreenState extends State<_CustomScenarioEditorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Custom Scenario', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'Enter your custom roleplay scenario...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
