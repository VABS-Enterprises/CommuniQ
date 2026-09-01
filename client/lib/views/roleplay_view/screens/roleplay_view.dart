import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/views/roleplay_view/widgets/roleplay_recent_practice.dart';
import 'package:communiq/views/roleplay_view/widgets/scenario_tile.dart';

/// The Practise tab: choose a scenario (or build a custom one) and start a
/// live voice session.
class RoleplayView extends StatefulWidget {
  const RoleplayView({super.key});

  @override
  State<RoleplayView> createState() => _RoleplayViewState();
}

class _RoleplayViewState extends State<RoleplayView> {
  String? _selectedKey;

  void _toggle(String key) => setState(
        () => _selectedKey = _selectedKey == key ? null : key,
      );

  void _start() => context.push(AppRoutes.roleplaySetup, extra: _selectedKey);

  @override
  Widget build(BuildContext context) {
    // The tab shows the first four scenarios; the rest live behind "See all".
    const featured = 4;
    final selected = presetForKey(_selectedKey);

    return PlayfulBackground(
      seed: 3,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s16,
              AppSpacing.page,
              AppSpacing.navClearance,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('PRACTISE', style: AppTextStyles.eyebrow),
                        const SizedBox(height: 2),
                        Text('Real conversations',
                            style: AppTextStyles.displaySmall),
                        const SizedBox(height: 4),
                        Text(
                          'Speak with an AI character and get scored.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Mascot(
                    mood: selected != null
                        ? MascotMood.listening
                        : MascotMood.idle,
                    size: 78,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              _StartCard(selected: selected, onStart: _start),
              const SizedBox(height: AppSpacing.section),

              SectionHeader(
                eyebrow: 'Scenarios',
                title: 'Pick a situation',
                actionLabel: kScenarioPresets.length > featured ? 'See all' : null,
                onAction: kScenarioPresets.length > featured
                    ? () => context.push(AppRoutes.roleplayScenarios)
                    : null,
              ),
              for (var i = 0; i < featured; i++)
                FadeInUp(
                  delay: AppMotion.staggerFor(i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.item),
                    child: ScenarioTile(
                      preset: kScenarioPresets[i],
                      selected: _selectedKey == kScenarioPresets[i].key,
                      onTap: () => _toggle(kScenarioPresets[i].key),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s16),

              const SectionHeader(
                eyebrow: 'History',
                title: 'Recent practice',
              ),
              const RoleplayRecentPractice(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary call to action. Reflects whether a scenario is chosen so the
/// button never lies about what tapping it will do.
class _StartCard extends StatelessWidget {
  const _StartCard({required this.selected, required this.onStart});

  final ScenarioPreset? selected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = selected;
    final tint = s?.color ?? AppColors.coral;

    return ChunkyCard(
      fill: AppColors.surface,
      borderColor: tint,
      accent: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconTile(
                icon: s?.icon ?? Icons.tune_rounded,
                color: tint,
                tinted: false,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s?.title ?? 'Custom roleplay',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s?.subtitle ??
                          'Design any scenario — practise what matters to you.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          ChunkyButton(
            label: s == null ? 'Build a scenario' : 'Configure & start',
            icon: Icons.mic_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
