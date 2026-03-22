class RoleplayConfig {
  final String scenario;
  final String persona;
  final String difficulty;
  final String category;
  final String tone;
  final String timeLimit;
  final String languageLevel;

  RoleplayConfig({
    required this.scenario,
    required this.persona,
    required this.difficulty,
    required this.category,
    this.tone = 'Neutral',
    this.timeLimit = '60 sec',
    this.languageLevel = 'Intermediate',
  });
}
