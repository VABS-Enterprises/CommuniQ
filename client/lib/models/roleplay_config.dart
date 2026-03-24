class RoleplayConfig {
  /// Firestore scenario document ID — required to call POST /sessions/start.
  final String scenarioId;

  /// Display title shown in the conversation and feedback screens.
  final String scenarioTitle;

  final String scenario;
  final String persona;
  final String difficulty;
  final String category;
  final String tone;
  final String timeLimit;
  final String languageLevel;

  RoleplayConfig({
    this.scenarioId = '',
    this.scenarioTitle = 'Roleplay Session',
    required this.scenario,
    required this.persona,
    required this.difficulty,
    required this.category,
    this.tone = 'Neutral',
    this.timeLimit = '60 sec',
    this.languageLevel = 'Intermediate',
  });
}
