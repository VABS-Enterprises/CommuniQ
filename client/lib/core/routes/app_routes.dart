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

  // ── Main tabs (shell branches) ───────────────────────────────────────────
  static const home = '/home';
  static const learning = '/learning';
  static const roleplay = '/roleplay';
  static const contest = '/contest';
  static const profile = '/profile';

  /// Tab order, used by the shell and the nav bar so the two can't disagree.
  static const tabs = [home, learning, roleplay, contest, profile];

  // ── Pushed over the shell ────────────────────────────────────────────────
  static const learningSession = '/learning/session';
  static const roleplaySetup = '/roleplay/setup';
  static const roleplayScenarios = '/roleplay/scenarios';
  static const roleplayConversation = '/roleplay/conversation';
  static const roleplayFeedback = '/roleplay/feedback';

  /// A past session's stored evaluation, opened from history.
  static const sessionReport = '/session-report';

  static const contestPlay = '/contest/play';
  static const contestResult = '/contest/result';
  static const contestHistory = '/contest/history';
  static const contestLeaderboard = '/contest/leaderboard';

  /// App-wide XP standings — distinct from [contestLeaderboard], which ranks
  /// contest scores.
  static const leaderboard = '/leaderboard';

  // ── Debug ────────────────────────────────────────────────────────────────
  static const devGallery = '/dev/gallery';
}

// ConversationArgs and FeedbackArgs live in app_router.dart, next to the
// GoRoute builders that cast `state.extra` to them. Duplicate stubs used to
// sit here with `dynamic config` and the wrong fields; a screen that imported
// this file built the stub, and the router's cast then failed at runtime.

