import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/routes/app_routes.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/models/contest_models.dart';
import 'package:communiq/models/onboarding_data.dart';

import 'package:communiq/views/auth/screens/login_screen.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
import 'package:communiq/views/contest_view/screens/contest_history_page.dart';
import 'package:communiq/views/contest_view/screens/contest_hub_page.dart';
import 'package:communiq/views/contest_view/screens/contest_leaderboard_page.dart';
import 'package:communiq/views/contest_view/screens/contest_play_page.dart';
import 'package:communiq/views/contest_view/screens/contest_result_page.dart';
import 'package:communiq/views/contest_view/screens/leaderboard_page.dart';
import 'package:communiq/views/dev/component_gallery.dart';
import 'package:communiq/views/home_view/screens/home_view.dart';
import 'package:communiq/views/learning_view/screens/learning_session_screen.dart';
import 'package:communiq/views/learning_view/screens/learning_view.dart';
import 'package:communiq/views/main_navigation_view/screens/app_shell.dart';
import 'package:communiq/views/onboarding/screens/commitment_screen.dart';
import 'package:communiq/views/onboarding/screens/communication_context_screen.dart';
import 'package:communiq/views/onboarding/screens/first_roleplay_screen.dart';
import 'package:communiq/views/onboarding/screens/goal_confirmation_screen.dart';
import 'package:communiq/views/onboarding/screens/goal_selection_screen.dart';
import 'package:communiq/views/onboarding/screens/level_selection_screen.dart';
import 'package:communiq/views/onboarding/screens/personal_challenges_screen.dart';
import 'package:communiq/views/onboarding/screens/plan_ready_screen.dart';
import 'package:communiq/views/onboarding/screens/roleplay_intro_screen.dart';
import 'package:communiq/views/onboarding/screens/skill_level_screen.dart';
import 'package:communiq/views/onboarding/screens/speaking_style_screen.dart';
import 'package:communiq/views/onboarding/screens/splash_screen.dart';
import 'package:communiq/views/onboarding/screens/transformation_screen.dart';
import 'package:communiq/views/onboarding/screens/validation_screen.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';
import 'package:communiq/views/premium_view/screens/premium_screen.dart';
import 'package:communiq/views/profile_view/screens/profile_view.dart';
import 'package:communiq/views/roleplay_view/screens/all_scenarios_page.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_view.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKeys = List.generate(
  AppRoutes.tabs.length,
  (i) => GlobalKey<NavigatorState>(debugLabel: 'tab$i'),
);

/// Republishes Firebase's auth stream as a [Listenable] so go_router
/// re-evaluates its redirect the moment sign-in or sign-out happens.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = AuthService.authStateChanges.listen((user) {
      final signedIn = user != null;
      if (signedIn != _signedIn) {
        _signedIn = signedIn;
        notifyListeners();
      }
      if (!_ready) {
        _ready = true;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<User?> _sub;

  bool _signedIn = false;
  bool _ready = false;

  bool get signedIn => _signedIn;

  /// False until Firebase reports its first auth state. Until then we hold on
  /// the splash screen rather than flashing the welcome screen at a user who
  /// turns out to be signed in.
  bool get ready => _ready;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authNotifier = _AuthNotifier();

/// Builds the app's router.
///
/// Replaces both the imperative `Navigator.push(MaterialPageRoute(...))` calls
/// scattered through the screens and the `Notification`-bubbling tab switch
/// that the old shell used.
GoRouter createRouter({bool gallery = false}) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: gallery ? AppRoutes.devGallery : AppRoutes.splash,
    refreshListenable: authNotifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // The gallery is a debug surface; never gate or redirect it.
      if (state.matchedLocation == AppRoutes.devGallery) return null;

      final loc = state.matchedLocation;

      // Hold on the splash until Firebase has reported an auth state.
      if (!authNotifier.ready) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final signedIn = authNotifier.signedIn;
      final inAuthFlow = loc == AppRoutes.splash ||
          loc == AppRoutes.welcome ||
          loc == AppRoutes.login ||
          loc == AppRoutes.signup ||
          loc.startsWith('/onboarding');

      // Signed in but still sitting on a pre-auth screen → into the app.
      // Onboarding is exempt: a new account finishes the funnel first.
      if (signedIn && inAuthFlow && !loc.startsWith('/onboarding')) {
        return AppRoutes.home;
      }

      // Signed out anywhere inside the app → back to welcome.
      if (!signedIn && !inAuthFlow) return AppRoutes.welcome;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (_, state) => _fade(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.devGallery,
        builder: (_, __) => const ComponentGallery(),
      ),

      // ── Onboarding funnel ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboardingContext,
        builder: (_, __) => const CommunicationContextScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingGoal,
        builder: (_, __) => const GoalSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingChallenges,
        builder: (_, state) =>
            PersonalChallengesScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingSkill,
        builder: (_, __) => const SkillLevelScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStyle,
        builder: (_, state) =>
            SpeakingStyleScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingLevel,
        builder: (_, state) =>
            LevelSelectionScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingConfirm,
        builder: (_, state) =>
            GoalConfirmationScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingCommitment,
        builder: (_, state) =>
            CommitmentScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingValidation,
        builder: (_, state) =>
            ValidationScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingTransformation,
        builder: (_, state) =>
            TransformationScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingFirstRoleplay,
        builder: (_, __) => const FirstRoleplayScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingRoleplayIntro,
        builder: (_, state) =>
            RoleplayIntroScreen(data: state.extra! as OnboardingData),
      ),
      GoRoute(
        path: AppRoutes.onboardingPlanReady,
        builder: (_, state) =>
            PlanReadyScreen(data: state.extra! as OnboardingData),
      ),

      // ── Main tabs ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKeys[0],
            routes: [
              GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeView()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[1],
            routes: [
              GoRoute(
                path: AppRoutes.learning,
                builder: (_, __) => const LearningView(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[2],
            routes: [
              GoRoute(
                path: AppRoutes.roleplay,
                builder: (_, __) => const RoleplayView(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[3],
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),

      // ── Pushed over the shell (full screen, no nav bar) ────────────────
      GoRoute(
        path: AppRoutes.learningSession,
        parentNavigatorKey: _rootKey,
        builder: (_, state) {
          final args = state.extra! as LearningSessionArgs;
          return LearningSessionScreen(
            level: args.level,
            isAlreadyCompleted: args.isAlreadyCompleted,
            initialCoins: args.initialCoins,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.roleplaySetup,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SetupScenarioPage(prefilledPresetKey: state.extra as String?),
      ),
      GoRoute(
        path: AppRoutes.roleplayScenarios,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AllScenariosPage(),
      ),
      // Conversation and feedback are reached via raw Navigator pushes from
      // SetupScenarioPage / RoleplayConversationScreen, not via go_router —
      // both screens need the full session/report objects those raw pushes
      // carry, which don't round-trip through a route's `extra` cleanly.
      // A go_router `roleplayConversation`/`roleplayFeedback` pair used to
      // live here but was never actually reached by that live flow — a
      // second, dead navigation path for the same two screens.

      GoRoute(
        path: AppRoutes.contest,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ContestHubPage(),
      ),
      GoRoute(
        path: AppRoutes.contestPlay,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ContestPlayPage(type: state.extra! as ContestType),
      ),
      GoRoute(
        path: AppRoutes.contestResult,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ContestResultPage(result: state.extra! as ContestResult),
      ),
      GoRoute(
        path: AppRoutes.contestHistory,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ContestHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.contestLeaderboard,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ContestLeaderboardPage(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LeaderboardPage(),
      ),
      GoRoute(
        path: AppRoutes.premium,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PremiumScreen(),
      ),
    ],
  );
}

/// Splash → welcome should cross-fade rather than slide; the old code used a
/// hand-built PageRouteBuilder for exactly this.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.celebrate,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

// ── Typed arguments for routes that carry objects ──────────────────────────
// go_router's `extra` is dynamic; these give each such route a checked shape
// instead of a bag of positional values.

class LearningSessionArgs {
  const LearningSessionArgs({
    required this.level,
    this.isAlreadyCompleted = false,
    this.initialCoins = 0,
  });

  final CommuniqLevel level;
  final bool isAlreadyCompleted;
  final int initialCoins;
}

