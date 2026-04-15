import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';
import '../widgets/categories_section.dart';
import '../widgets/roleplay_recent_practice.dart';
import '../widgets/start_roleplay_card.dart';

class RoleplayView extends StatefulWidget {
  const RoleplayView({super.key});

  @override
  State<RoleplayView> createState() => _RoleplayViewState();
}

class _RoleplayViewState extends State<RoleplayView> {
  Map<String, dynamic>? _selectedScenario;

  void _onScenarioSelect(Map<String, dynamic>? scenario) {
    setState(() {
      if (_selectedScenario != null && scenario != null && _selectedScenario!['title'] == scenario['title']) {
        // Deselect if clicking the same one again
        _selectedScenario = null;
      } else {
        _selectedScenario = scenario;
      }
    });
  }

  void _onStart() {
    if (_selectedScenario != null) {
      // Prebuilt selected - navigate to new Setup Scenario Page with prefilled values
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetupScenarioPage(
            prefilledTitle: _selectedScenario!['title'],
            prefilledScenario: _selectedScenario!['scenario'],
            prefilledPersona: _selectedScenario!['persona'],
            prefilledMood: 'Neutral',
            prefilledLevel: 'Medium',
          ),
        ),
      );
    } else {
      // Custom / No selection - navigate to Setup Scenario Page in clean state
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SetupScenarioPage(),
        ),
      );
    }
  }

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
                
                // 1. Header
                const Text(
                  'Roleplay',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Practice real-life conversations',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32.0),
                
                // 2. Custom Roleplay / Start Button
                StartRoleplayCard(
                  onStart: _onStart,
                  isCustom: _selectedScenario == null,
                ),
                const SizedBox(height: 32.0),
                
                // 3. Scenarios Grid (2x2) with selection logic
                CategoriesSection(
                  selectedScenario: _selectedScenario,
                  onSelect: _onScenarioSelect,
                ),
                const SizedBox(height: 32.0),
                
                // 4. Recent Practice List (4 items)
                const RoleplayRecentPractice(),
                
                const SizedBox(height: 120.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
