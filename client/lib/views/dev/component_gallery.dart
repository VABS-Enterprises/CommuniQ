import 'package:flutter/material.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/confetti_overlay.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/option_card.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/section_header.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/common_widgets/stat_pill.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/spacing.dart';

/// Debug-only catalogue of the design system: every component, in every state.
///
/// This is the review surface for the visual language — it is far faster to
/// judge (and regression-check) the system here than by clicking through the
/// real app. Not reachable from any user-facing route.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  int _selectedOption = 1;
  bool _loadingDemo = false;
  bool _confetti = false;
  double _progress = 0.65;

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      play: _confetti,
      child: PlayfulBackground(
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          appBar: AppBar(
            title: const Text('Design System'),
            actions: const [
              StatPill(icon: Icons.local_fire_department_rounded, value: '5', compact: true),
              SizedBox(width: 8),
              StatPill(
                icon: Icons.bolt_rounded,
                value: '1,240',
                compact: true,
                color: AppColors.info,
              ),
              SizedBox(width: 16),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s64,
            ),
            children: [
              // ── Mascot ──────────────────────────────────────────────────
              const SectionHeader(
                eyebrow: 'Character',
                title: 'Whisperwing',
              ),
              ChunkyCard(
                child: Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s16,
                  alignment: WrapAlignment.center,
                  children: MascotMood.values
                      .map(
                        (m) => SizedBox(
                          width: 96,
                          child: Column(
                            children: [
                              Mascot(mood: m, size: 78),
                              const SizedBox(height: 4),
                              Text(m.name, style: AppTextStyles.labelSmall),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Buttons ─────────────────────────────────────────────────
              const SectionHeader(
                eyebrow: 'Actions',
                title: 'Buttons',
              ),
              ChunkyButton(
                label: 'Primary — start practising',
                icon: Icons.mic_rounded,
                onPressed: () => setState(() => _confetti = !_confetti),
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
              ),
              ChunkyButton(
                label: 'Secondary',
                variant: ChunkyButtonVariant.secondary,
                onPressed: () {},
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
              ),
              ChunkyButton(
                label: 'Success',
                variant: ChunkyButtonVariant.success,
                icon: Icons.check_rounded,
                onPressed: () {},
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
              ),
              ChunkyButton(
                label: 'Danger',
                variant: ChunkyButtonVariant.danger,
                onPressed: () {},
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
              ),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: 'Disabled',
                      onPressed: null,
                      size: ChunkyButtonSize.sm,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Loading',
                      loading: _loadingDemo,
                      size: ChunkyButtonSize.sm,
                      onPressed: () async {
                        setState(() => _loadingDemo = true);
                        await Future.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _loadingDemo = false);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: ChunkyButton(
                      label: 'Ghost',
                      variant: ChunkyButtonVariant.ghost,
                      size: ChunkyButtonSize.sm,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Cards ───────────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Surfaces', title: 'Cards'),
              const ChunkyCard(
                child: Text(
                  'Static card — soft shadow, not pressable.',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ChunkyCard(
                onTap: () {},
                child: const Text(
                  'Tappable card — hard shadow, presses down.',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ChunkyCard(
                accent: AppColors.grape,
                onTap: () {},
                child: const Text(
                  'Accent stripe, for colour-coding by category.',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Options ─────────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Input', title: 'Option cards'),
              ...List.generate(3, (i) {
                const titles = ['Job interviews', 'Public speaking', 'Daily conversation'];
                const subs = ['Land the offer', 'Own the room', 'Everyday fluency'];
                const icons = [
                  Icons.work_rounded,
                  Icons.campaign_rounded,
                  Icons.chat_bubble_rounded,
                ];
                const accents = [AppColors.coral, AppColors.sun, AppColors.teal];
                return OptionCard(
                  title: titles[i],
                  subtitle: subs[i],
                  icon: icons[i],
                  accent: accents[i],
                  selected: _selectedOption == i,
                  onTap: () => setState(() => _selectedOption = i),
                );
              }),
              const SizedBox(height: AppSpacing.s16),

              // ── Progress ────────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Feedback', title: 'Progress'),
              ChunkyCard(
                child: Column(
                  children: [
                    ChunkyProgressBar(
                      value: _progress,
                      showLabel: true,
                      label: 'Level 4 · ${(_progress * 100).round()}%',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    ChunkyProgressBar(value: 0.35, color: AppColors.coral, height: 12),
                    const SizedBox(height: AppSpacing.s12),
                    ChunkyProgressBar(value: 0.9, color: AppColors.info, height: 12),
                    const SizedBox(height: AppSpacing.s16),
                    Slider(
                      value: _progress,
                      onChanged: (v) => setState(() => _progress = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Tiles & badges ──────────────────────────────────────────
              const SectionHeader(eyebrow: 'Accents', title: 'Tiles & badges'),
              ChunkyCard(
                child: Column(
                  children: [
                    Wrap(
                      spacing: AppSpacing.s12,
                      runSpacing: AppSpacing.s12,
                      children: const [
                        IconTile(icon: Icons.mic_rounded, color: AppColors.coral),
                        IconTile(icon: Icons.school_rounded, color: AppColors.grape),
                        IconTile(icon: Icons.emoji_events_rounded, color: AppColors.sun),
                        IconTile(icon: Icons.trending_up_rounded, color: AppColors.teal),
                        IconTile(
                          icon: Icons.bolt_rounded,
                          color: AppColors.coral,
                          tinted: false,
                        ),
                        IconTile(
                          icon: Icons.check_rounded,
                          color: AppColors.success,
                          tinted: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: const [
                        CountBadge(label: 'NEW'),
                        CountBadge(label: '#1', color: AppColors.sun, icon: Icons.star_rounded),
                        CountBadge(label: '3 left', color: AppColors.teal),
                        CountBadge(label: 'LOCKED', color: AppColors.inkSoft),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── States ──────────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Screens', title: 'Empty / error / loading'),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 340,
                  child: EmptyState(
                    title: 'No sessions yet',
                    message: 'Finish your first practice session and it will show up here.',
                    actionLabel: 'Start practising',
                    onAction: () {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 340,
                  child: ErrorStateView(
                    message: "We couldn't reach the server. Check your connection.",
                    onRetry: () {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              const ChunkyCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 200,
                  child: LoadingStateView(label: 'Scoring your answer…'),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ChunkyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Skeletons', style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.s12),
                    const SkeletonBox(width: 160, height: 20),
                    const SizedBox(height: AppSpacing.s8),
                    const SkeletonBox(height: 14),
                    const SizedBox(height: AppSpacing.s8),
                    const SkeletonBox(width: 220, height: 14),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Type scale ──────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Foundation', title: 'Type — Nunito'),
              ChunkyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Display L', style: AppTextStyles.displayLarge),
                    Text('Headline L', style: AppTextStyles.headlineLarge),
                    Text('Title L', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Body large — the quick brown fox jumps over the lazy dog.',
                      style: AppTextStyles.bodyLarge,
                    ),
                    Text(
                      'Body medium — the quick brown fox jumps over the lazy dog.',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('EYEBROW LABEL', style: AppTextStyles.eyebrow),
                    Text('1,240', style: AppTextStyles.numeral),
                    Text(
                      '"Quoted transcript text looks like this."',
                      style: AppTextStyles.quote,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Palette ─────────────────────────────────────────────────
              const SectionHeader(eyebrow: 'Foundation', title: 'Palette'),
              ChunkyCard(
                child: Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: const [
                    _Swatch('coral', AppColors.coral),
                    _Swatch('sun', AppColors.sun),
                    _Swatch('teal', AppColors.teal),
                    _Swatch('grape', AppColors.grape),
                    _Swatch('success', AppColors.success),
                    _Swatch('error', AppColors.error),
                    _Swatch('info', AppColors.info),
                    _Swatch('ink', AppColors.ink),
                    _Swatch('bgSunk', AppColors.bgSunk, dark: false),
                    _Swatch('outline', AppColors.outline, dark: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, {this.dark = true});

  final String name;
  final Color color;

  /// Whether the swatch needs light text on it.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 58,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelSmall.copyWith(
          color: dark ? AppColors.inkOnDark : AppColors.ink,
        ),
      ),
    );
  }
}
