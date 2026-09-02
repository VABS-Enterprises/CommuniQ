import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/contest_service.dart';
import 'package:communiq/models/contest_models.dart';
import 'package:communiq/views/contest_view/contest_prompts.dart';

/// Write an answer to today's prompt and submit it for scoring.
class ContestPlayPage extends StatefulWidget {
  const ContestPlayPage({super.key, required this.type});

  final ContestType type;

  @override
  State<ContestPlayPage> createState() => _ContestPlayPageState();
}

class _ContestPlayPageState extends State<ContestPlayPage> {
  final TextEditingController _answer = TextEditingController();
  late final String _prompt = promptFor(widget.type);

  /// Debate is the only format where a side has to be chosen.
  String? _position;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.type == ContestType.debate) _position = kDebatePositions.first;
    _answer.addListener(_onChanged);
  }

  @override
  void dispose() {
    _answer.removeListener(_onChanged);
    _answer.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int get _length => _answer.text.trim().length;

  /// Mirrors the server's bounds so the button is disabled rather than the
  /// submission bouncing back as a 400.
  bool get _canSubmit =>
      !_submitting &&
      _length >= ContestService.minAnswerLength &&
      _length <= ContestService.maxAnswerLength;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ContestService.instance.submit(
        type: widget.type,
        answer: _answer.text,
        motion: _prompt,
        position: _position,
      );
      if (!mounted) return;
      // Replace so Back from the result returns to the hub, not to a filled-in
      // form that has already been submitted.
      context.pushReplacement(AppRoutes.contestResult, extra: result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.type.color;

    return PlayfulBackground(
      seed: 8,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: Text(widget.type.label),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s32,
            ),
            children: [
              ChunkyCard(
                accent: tint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("TODAY'S PROMPT", style: AppTextStyles.eyebrow),
                    const SizedBox(height: 6),
                    Text(_prompt, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              if (widget.type == ContestType.debate) ...[
                Text('Your side', style: AppTextStyles.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    for (final side in kDebatePositions)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: side == kDebatePositions.first
                                ? AppSpacing.s10
                                : 0,
                          ),
                          child: ChunkyButton(
                            label: side == 'for' ? 'For' : 'Against',
                            variant: _position == side
                                ? ChunkyButtonVariant.primary
                                : ChunkyButtonVariant.secondary,
                            size: ChunkyButtonSize.sm,
                            onPressed: () => setState(() => _position = side),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              Text('Your answer', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppSpacing.s8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.buttonRadius,
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                child: TextField(
                  controller: _answer,
                  maxLines: 10,
                  minLines: 7,
                  maxLength: ContestService.maxAnswerLength,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Make your case. Structure it, back it up, and '
                        'address the obvious counter-argument…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.all(AppSpacing.s14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _length < ContestService.minAnswerLength
                    ? 'At least ${ContestService.minAnswerLength} characters '
                        '($_length so far)'
                    : '$_length / ${ContestService.maxAnswerLength}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _length > ContestService.maxAnswerLength
                      ? AppColors.error
                      : AppColors.inkSoft,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s12),
                ChunkyCard(
                  fill: AppColors.errorSoft,
                  borderColor: AppColors.error,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s20),
              if (_submitting)
                Column(
                  children: [
                    const Mascot(mood: MascotMood.thinking, size: 88),
                    const SizedBox(height: AppSpacing.s8),
                    Text('Scoring your answer…',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                ),
              ChunkyButton(
                label: 'Submit for scoring',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
