import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/session_result_model.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_feedback_screen.dart';

/// A past roleplay session's stored evaluation, opened from Recent practice.
///
/// Loads GET /sessions/:id/report and renders it with the same
/// [RoleplayFeedbackScreen] a just-finished session uses, in read-only mode
/// (no XP celebration, no re-run actions, nothing saved).
class SessionReportPage extends StatefulWidget {
  const SessionReportPage({
    super.key,
    required this.sessionId,
    this.scenarioTitle,
  });

  final String sessionId;
  final String? scenarioTitle;

  @override
  State<SessionReportPage> createState() => _SessionReportPageState();
}

class _SessionReportPageState extends State<SessionReportPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      SessionService.instance.fetchSessionReport(widget.sessionId);

  void _retry() => setState(() => _future = _load());

  /// History rows carry the title; fall back to the preset the server stored
  /// as `scenarioType`, then to a neutral label.
  String _titleFor(Map<String, dynamic> raw) {
    final t = widget.scenarioTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    final type = raw['scenarioType'];
    final preset =
        presetForKey(presetKeyForRecommendation(type is String ? type : null));
    return preset?.title ?? 'Practice Session';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _shell(
            context,
            const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _shell(context, _error(snap.error));
        }
        final raw = snap.data!;
        final report = SessionReport.fromJson(raw);
        return RoleplayFeedbackScreen(
          config: report.toFeedbackConfig(_titleFor(raw)),
          report: report,
          sessionId: widget.sessionId,
          readOnly: true,
        );
      },
    );
  }

  Widget _shell(BuildContext context, Widget body) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 18),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.roleplay),
        ),
        title: Text(
          widget.scenarioTitle?.isNotEmpty == true
              ? widget.scenarioTitle!
              : 'Session Report',
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _error(Object? error) {
    final msg = (error?.toString() ?? '').replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.inkSoft),
            const SizedBox(height: AppSpacing.s12),
            const Text(
              "Couldn't load this report",
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            FilledButton(
              onPressed: _retry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
