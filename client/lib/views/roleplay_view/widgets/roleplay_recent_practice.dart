import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

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
              .take(4) // Show 4 items
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
        const Text(
          'Recent Practice',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ),
          )
        else if (_error)
          _buildErrorState(context)
        else if (_sessions.isEmpty)
          _buildEmptyState(context)
        else
          ..._sessions.map((s) => _buildCompactRow(context, s)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Could not load recent practice.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.mic_none_rounded, color: AppColors.textMuted, size: 32),
            const SizedBox(height: 10),
            const Text(
              'No practice sessions yet\nStart your first roleplay!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRow(BuildContext context, Map<String, dynamic> session) {
    final title = session['scenarioTitle'] as String? ?? 'Session';
    final subtitle = _formatSubtitle(session);
    final score = _formatScore(session);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoleplaySetupScreen(
              mode: 'prefilled',
              category: 'Custom',
              scenario: title,
              persona: session['persona'] ?? 'Friendly Colleague',
              difficulty: session['difficulty'] ?? 'Medium',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                    ),
                    child: const Icon(Icons.history, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Text(
                  score,
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
