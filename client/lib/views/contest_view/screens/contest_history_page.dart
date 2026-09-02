import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/playful_background.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/services/contest_service.dart';
import 'package:communiq/models/contest_models.dart';
import 'package:communiq/views/contest_view/screens/contest_hub_page.dart';

/// Every contest attempt this user has made, newest first.
///
/// Replaces the old page that rendered a hardcoded list of three invented
/// contests from contest_state.dart.
class ContestHistoryPage extends StatefulWidget {
  const ContestHistoryPage({super.key});

  @override
  State<ContestHistoryPage> createState() => _ContestHistoryPageState();
}

class _ContestHistoryPageState extends State<ContestHistoryPage> {
  List<ContestAttempt> _attempts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attempts = await ContestService.instance.history(limit: 50);
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlayfulBackground(
      seed: 10,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          title: const Text('Contest history'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    if (_error != null) {
      return ErrorStateView(message: _error, onRetry: _load);
    }

    if (_attempts.isEmpty) {
      return const EmptyState(
        title: 'No attempts yet',
        message: 'Your contest scores will appear here.',
        mood: MascotMood.encouraging,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s12,
          AppSpacing.page,
          AppSpacing.s32,
        ),
        itemCount: _attempts.length,
        itemBuilder: (context, i) => FadeInUp(
          delay: AppMotion.staggerFor(i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: ContestAttemptRow(attempt: _attempts[i]),
          ),
        ),
      ),
    );
  }
}
