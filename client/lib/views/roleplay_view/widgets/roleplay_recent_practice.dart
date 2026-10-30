import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/routes/app_router.dart' show SessionReportArgs;
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/activity_bus.dart';
import 'package:communiq/core/services/session_service.dart';

/// Completed practice sessions, most recent first.
class RoleplayRecentPractice extends StatefulWidget {
  const RoleplayRecentPractice({super.key});

  @override
  State<RoleplayRecentPractice> createState() => _RoleplayRecentPracticeState();
}

class _RoleplayRecentPracticeState extends State<RoleplayRecentPractice> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    // The Practise tab stays alive in the shell's IndexedStack, so a session
    // finished on top of it would otherwise never appear here.
    ActivityBus.instance.addListener(_onActivity);
    _load();
  }

  @override
  void dispose() {
    ActivityBus.instance.removeListener(_onActivity);
    super.dispose();
  }

  void _onActivity() {
    if (ActivityBus.instance.last == ActivityKind.roleplay) {
      // Reload quietly: keep showing the current rows instead of a skeleton.
      _load(showSkeleton: _sessions.isEmpty);
    }
  }

  Future<void> _load({bool showSkeleton = true}) async {
    if (!mounted) return;
    setState(() {
      _loading = showSkeleton;
      _error = false;
    });
    try {
      final sessions = await SessionService.instance.fetchSessionHistory();
      if (!mounted) return;
      setState(() {
        _sessions = sessions
            .where((s) => s['status'] == 'completed')
            .take(4)
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[RoleplayRecentPractice] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: ChunkyCard(
              padding: const EdgeInsets.all(AppSpacing.s14),
              child: Row(
                children: const [
                  SkeletonBox(width: 40, height: 40),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(child: SkeletonBox(height: 16)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_error) {
      return ChunkyCard(
        fill: AppColors.errorSoft,
        borderColor: AppColors.error,
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Text(
                "Couldn't load your history.",
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
              ),
            ),
            TextButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return ChunkyCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          title: 'Nothing yet',
          message: 'Finish a session and it will show up here.',
          mood: MascotMood.encouraging,
          actionLabel: 'Start one',
          onAction: () => context.push(AppRoutes.roleplaySetup),
        ),
      );
    }

    return Column(
      children: [
        for (final s in _sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: _PracticeRow(session: s),
          ),
      ],
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({required this.session});

  final Map<String, dynamic> session;

  /// Firestore documents are untyped, so every field is defensively read.
  String get _title {
    final t = session['scenarioTitle'] ?? session['scenarioId'];
    return t is String && t.isNotEmpty ? t : 'Practice session';
  }

  int? get _score {
    final raw = session['overallScore'] ?? session['score'];
    return raw is num ? raw.round() : null;
  }

  /// Only a completed session has a stored evaluation to open.
  String? get _reportSessionId {
    final id = session['sessionId'];
    if (session['status'] != 'completed' || id is! String || id.isEmpty) {
      return null;
    }
    return id;
  }

  String get _when {
    // Sessions carry `startedAt` / `endedAt` (ISO strings) — never createdAt.
    final raw = session['startedAt'] ?? session['endedAt'];
    DateTime? dt;
    if (raw is String) dt = DateTime.tryParse(raw)?.toLocal();
    if (raw is int) {
      // Firestore may hand back seconds rather than milliseconds.
      dt = DateTime.fromMillisecondsSinceEpoch(
        raw > 100000000000 ? raw : raw * 1000,
      );
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final tint = score != null ? AppColors.forScore(score) : AppColors.inkSoft;
    final reportId = _reportSessionId;

    return ChunkyCard(
      onTap: reportId == null
          ? null
          : () => context.push(
                AppRoutes.sessionReport,
                extra: SessionReportArgs(
                  sessionId: reportId,
                  scenarioTitle: session['scenarioTitle'] is String
                      ? session['scenarioTitle'] as String
                      : null,
                ),
              ),
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(
        children: [
          IconTile(icon: Icons.mic_rounded, color: tint, size: 40),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_when, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                '$score',
                style: AppTextStyles.numeralSmall.copyWith(
                  color: AppColors.inkOnDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
