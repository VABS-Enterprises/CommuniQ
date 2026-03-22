import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import '../widgets/avatar_hero_section.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/todays_progress_card.dart';
import '../widgets/quick_actions_row.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppColors.background),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24.0),
                    const HomeTopBar(),
                    const SizedBox(height: 32.0),
                    const AvatarHeroSection(),
                    const SizedBox(height: 32.0),
                    const TodaysProgressCard(),
                    const SizedBox(height: 24.0),
                    GradientButton(
                      text: 'Resume Training',
                      width: double.infinity,
                      onPressed: () {
                        // primary action
                      },
                    ),
                    const SizedBox(height: 24.0),
                    const QuickActionsRow(),
                    const SizedBox(height: 24.0),
                    const RecentActivitySection(),
                    const SizedBox(height: 96.0), // Padding for bottom navbar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
