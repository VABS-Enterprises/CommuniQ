/// Route paths, in one place.
///
/// Use these constants rather than raw string literals at call sites — a typo
/// in `context.go('/rolepaly')` is a runtime failure, whereas a typo here is a
/// compile error everywhere it is used.
abstract final class AppRoutes {
  // ── Pre-auth ─────────────────────────────────────────────────────────────
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';

  // ── Onboarding funnel ────────────────────────────────────────────────────
  // A flat chain rather than nested children: each step is independently
  // addressable, so a user resuming a half-finished funnel can be sent
  // straight to where they stopped.
  static const onboardingContext = '/onboarding/context';
  static const onboardingGoal = '/onboarding/goal';
  static const onboardingChallenges = '/onboarding/challenges';
  static const onboardingSkill = '/onboarding/skill';
  static const onboardingStyle = '/onboarding/style';
  static const onboardingLevel = '/onboarding/level';
  static const onboardingConfirm = '/onboarding/confirm';
  static const onboardingCommitment = '/onboarding/commitment';
  static const onboardingValidation = '/onboarding/validation';
  static const onboardingTransformation = '/onboarding/transformation';
  static const onboardingFirstRoleplay = '/onboarding/first-roleplay';
  static const onboardingRoleplayIntro = '/onboarding/roleplay-intro';
  static const onboardingPlanReady = '/onboarding/plan-ready';

  // ── Main tabs (shell branches) ───────────────────────────────────────────
  static const home = '/home';
  static const learning = '/learning';
  static const roleplay = '/roleplay';
  static const profile = '/profile';

  /// Tab order, used by the shell and the nav bar so the two can't disagree.
  static const tabs = [home, learning, roleplay, profile];

  // ── Pushed over the shell ────────────────────────────────────────────────
  static const learningSession = '/learning/session';
  static const roleplaySetup = '/roleplay/setup';
  static const roleplayScenarios = '/roleplay/scenarios';
  static const roleplayConversation = '/roleplay/conversation';
  static const roleplayFeedback = '/roleplay/feedback';
  static const sessionReport = '/session-report';

  static const contest = '/contest';
  static const contestPlay = '/contest/play';
  static const contestResult = '/contest/result';
  static const contestHistory = '/contest/history';
  static const contestLeaderboard = '/contest/leaderboard';

  /// App-wide XP standings — distinct from [contestLeaderboard], which ranks
  /// contest scores.
  static const leaderboard = '/leaderboard';

  static const premium = '/premium';

  // ── Debug ────────────────────────────────────────────────────────────────
  static const devGallery = '/dev/gallery';
}

/// Navigation arguments for [AppRoutes.roleplayConversation].
class ConversationArgs {
  final dynamic config;
  final String sessionId;

  const ConversationArgs({
    required this.config,
    required this.sessionId,
  });
}

/// Navigation arguments for [AppRoutes.roleplayFeedback].
class FeedbackArgs {
  final String sessionId;
  final dynamic result;

  const FeedbackArgs({
    required this.sessionId,
    this.result,
  });
}

