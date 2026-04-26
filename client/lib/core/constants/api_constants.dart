class ApiConstants {
  ApiConstants._();

  // Auth endpoints
  static const String authMe = '/auth/me';
  static const String authRegister = '/auth/register';
  static const String authGoogle = '/auth/google';

  // Onboarding endpoints
  static const String onboarding = '/onboarding';
  static const String onboardingDemo = '/onboarding/demo';
  static const String onboardingTranscribe = '/onboarding/transcribe';

  // Session endpoints
  static const String scenarios = '/scenarios';
  static const String sessionsStart = '/sessions/start';
  static const String sessionsOpening = '/sessions/opening';
  static const String sessionsTurn = '/sessions/turn';
  static const String sessionsEnd = '/sessions/end';
  static const String sessionsAbandon = '/sessions/abandon';
  static const String sessionsHistory = '/sessions/history';

  // CP2: LiveKit token endpoint — used when live voice mode is enabled
  static const String sessionsLivekitToken = '/sessions/livekit-token';

  // User profile (full Firestore doc, includes skillProgress)
  static const String userProfile = '/user/profile';

  // Leaderboards
  static const String leaderboard = '/leaderboard';
  static const String leaderboardWeekly = '/leaderboard/weekly';
}
