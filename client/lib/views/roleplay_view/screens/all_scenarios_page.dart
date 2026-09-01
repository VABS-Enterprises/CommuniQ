import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/views/roleplay_view/widgets/scenario_tile.dart';

/// The full scenario catalogue.
///
/// Renders every entry in [kScenarioPresets]. The previous version kept its
/// own four-item list, so three scenarios could not be discovered here at all.
class AllScenariosPage extends StatelessWidget {
  const AllScenariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 5,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: const Text('All scenarios'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            AppSpacing.s48,
          ),
          children: [
            Text(
              'Pick a situation to practise. You can tune the persona, tone '
              'and difficulty on the next screen.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s20),
            for (var i = 0; i < kScenarioPresets.length; i++)
              FadeInUp(
                delay: AppMotion.staggerFor(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.item),
                  child: ScenarioTile(
                    preset: kScenarioPresets[i],
                    selected: false,
                    // Choosing here goes straight to setup, prefilled.
                    onTap: () => context.pushReplacement(
                      AppRoutes.roleplaySetup,
                      extra: kScenarioPresets[i].key,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
