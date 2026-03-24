import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';
import '../widgets/ai_persona_section.dart';
import '../widgets/categories_section.dart';
import '../widgets/difficulty_section.dart';
import '../widgets/roleplay_header.dart';
import '../widgets/roleplay_recent_practice.dart';
import '../widgets/roleplay_top_bar.dart';
import '../widgets/start_roleplay_card.dart';

class RoleplayView extends StatefulWidget {
  const RoleplayView({super.key});

  @override
  State<RoleplayView> createState() => _RoleplayViewState();
}

class _RoleplayViewState extends State<RoleplayView> {
  String _selectedDifficulty = 'Medium';
  String _selectedPersona = 'Strict Boss';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24.0),
                const RoleplayTopBar(),
                const SizedBox(height: 32.0),
                const RoleplayHeader(),
                const SizedBox(height: 24.0),
                StartRoleplayCard(
                  onStart: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleplaySetupScreen(
                        mode: 'custom',
                        difficulty: _selectedDifficulty,
                        persona: _selectedPersona,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32.0),
                const CategoriesSection(),
                const SizedBox(height: 32.0),
                DifficultySection(
                  initialDifficulty: _selectedDifficulty,
                  onChanged: (value) => setState(() => _selectedDifficulty = value),
                ),
                const SizedBox(height: 32.0),
                AiPersonaSection(
                  initialPersona: _selectedPersona,
                  onChanged: (value) => setState(() => _selectedPersona = value),
                ),
                const SizedBox(height: 32.0),
                const RoleplayRecentPractice(),
                const SizedBox(height: 32.0),
                GradientButton(
                  text: 'Start Roleplay',
                  width: double.infinity,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleplaySetupScreen(
                        mode: 'custom',
                        difficulty: _selectedDifficulty,
                        persona: _selectedPersona,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 120.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
