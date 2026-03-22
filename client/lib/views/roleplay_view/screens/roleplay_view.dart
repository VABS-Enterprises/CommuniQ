import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import '../widgets/ai_persona_section.dart';
import '../widgets/categories_section.dart';
import '../widgets/difficulty_section.dart';
import '../widgets/roleplay_header.dart';
import '../widgets/roleplay_recent_practice.dart';
import '../widgets/roleplay_top_bar.dart';
import '../widgets/start_roleplay_card.dart';

class RoleplayView extends StatelessWidget {
  const RoleplayView({super.key});

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
                const StartRoleplayCard(),
                const SizedBox(height: 32.0),
                const CategoriesSection(),
                const SizedBox(height: 32.0),
                const DifficultySection(),
                const SizedBox(height: 32.0),
                const AiPersonaSection(),
                const SizedBox(height: 32.0),
                const RoleplayRecentPractice(),
                const SizedBox(height: 32.0),
                GradientButton(
                  text: 'Start Roleplay',
                  width: double.infinity,
                  onPressed: () {},
                ),
                const SizedBox(height: 120.0), // Padding to clear Floating Nav Bar + extra space
              ],
            ),
          ),
        ),
      ),
    );
  }
}
