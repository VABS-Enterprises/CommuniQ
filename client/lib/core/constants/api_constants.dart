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

  // Learning module endpoints
  static const String levels = '/levels';
  static const String levelsEvaluate = '/levels/evaluate';

  // Server-authoritative learning-module progress/grading (MCQ answers are
  // graded server-side — the client must never compute correctness/coins
  // locally for these).
  static const String learningProgress = '/learning/progress';
  static const String learningAnswer = '/learning/answer';
  // Full endpoint is '${learningLevelsBase}/$levelId/complete'.
  static const String learningLevelsBase = '/learning/levels';

  // User profile (full Firestore doc, includes skillProgress)
  static const String userProfile = '/user/profile';
  // Data-governance opt-in/out for training-data use (paper §3.6)
  static const String userTrainingConsent = '/user/training-consent';
  // Self-learning evaluation model transparency data (skillHistory, etc.)
  static const String userEvaluationProfile = '/user/evaluation-profile';

  // Leaderboards
  static const String leaderboard = '/leaderboard';
  static const String leaderboardWeekly = '/leaderboard/weekly';
}
