import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/session_service.dart';

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final sessions = await SessionService.instance.fetchSessionHistory();
      if (mounted) {
        setState(() {
          _sessions = sessions
              .where((s) => s['status'] == 'completed')
              .take(2)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Practice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.s16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          )
        else if (_error)
          _buildErrorState(context)
        else if (_sessions.isEmpty)
          _buildEmptyState(context)
        else
          ..._sessions.map((s) => _buildCompactRow(
                context,
                s['scenarioTitle'] as String? ?? 'Session',
                _formatSubtitle(s),
                _formatScore(s),
              )),
      ],
    );
  }

  String _formatSubtitle(Map<String, dynamic> session) {
    final startedAt = session['startedAt'];
    if (startedAt == null) return 'Completed';
    try {
      final dt = DateTime.parse(startedAt.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today • Completed';
      if (diff.inDays == 1) return '1 day ago • Completed';
      return '${diff.inDays} days ago • Completed';
    } catch (_) {
      return 'Completed';
    }
  }

  String _formatScore(Map<String, dynamic> session) {
    final score = session['overallScore'];
    return score != null ? '$score%' : '--';
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              'Could not load recent practice.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.mic_none_rounded,
                color: AppColors.textMuted, size: 32),
            const SizedBox(height: 10),
            Text(
              'No practice sessions yet\nStart your first roleplay!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRow(
    BuildContext context,
    String title,
    String subtitle,
    String score,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: const Icon(
                  Icons.history,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (score != '--')
                Text(
                  'SCORE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 8,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
