class ApiConstants {
  ApiConstants._();

  // Auth endpoints
  static const String authMe = '/auth/me';
  static const String authRegister = '/auth/register';
  static const String authGoogle = '/auth/google';

  // Session endpoints
  static const String scenarios = '/scenarios';
  static const String sessionsStart = '/sessions/start';
  static const String sessionsTurn = '/sessions/turn';
  static const String sessionsEnd = '/sessions/end';
  static const String sessionsAbandon = '/sessions/abandon';
  static const String sessionsHistory = '/sessions/history';
}
