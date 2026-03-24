import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/models/user_profile.dart';
import 'package:communiq/views/home_view/widgets/quick_actions_row.dart';
import '../widgets/avatar_hero_section.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/todays_progress_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  UserProfile? _profile;
  bool _profileError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() { _profileError = false; _isLoading = true; });
    try {
      final profile = await SessionService.instance.fetchProfile();
      if (mounted) setState(() { _profile = profile; _isLoading = false; });
    } catch (e) {
      debugPrint('[HomeView] fetchProfile failed: $e');
      if (mounted) setState(() { _profileError = true; _isLoading = false; });
    }
  }

  void _goToRoleplay() {
    SwitchToRoleplayTabNotification().dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppColors.background),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24.0),
                      HomeTopBar(profile: _profile),
                      const SizedBox(height: 32.0),
                      AvatarHeroSection(photoURL: _profile?.photoURL),
                      const SizedBox(height: 32.0),
                      if (_isLoading)
                        _buildProfileSkeleton()
                      else
                        TodaysProgressCard(profile: _profile),
                      if (_profileError) ...[
                        const SizedBox(height: 12.0),
                        _buildProfileErrorBanner(),
                      ],
                      const SizedBox(height: 24.0),
                      GradientButton(
                        text: 'Start Training',
                        width: double.infinity,
                        onPressed: _goToRoleplay,
                      ),
                      const SizedBox(height: 24.0),
                      const QuickActionsRow(),
                      const SizedBox(height: 24.0),
                      const RecentActivitySection(),
                      const SizedBox(height: 96.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildProfileErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load profile data. Pull down to retry.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: _loadProfile,
            child: const Text(
              'Retry',
              style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
