// Data models for the post-session feedback screen.
// Kept in the model layer so that SessionReport.toFeedbackConfig can build
// these without a circular dependency on a view file.

class SkillCard {
  final String title;
  final int score;
  final List<String> tags;
  const SkillCard({required this.title, required this.score, required this.tags});
}

class FeedbackConfig {
  final String scenarioTitle;
  final int overallScore;
  final List<SkillCard> skills;
  final List<String> insights;
  final List<String> improvements;

  const FeedbackConfig({
    required this.scenarioTitle,
    required this.overallScore,
    required this.skills,
    required this.insights,
    required this.improvements,
  });
}
