/// Data models for the post-session feedback screen.
/// Kept in the model layer so that [SessionReport.toFeedbackConfig] can build
/// these without a circular dependency on a view file.

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

  static FeedbackConfig demo = const FeedbackConfig(
    scenarioTitle: 'Salary Negotiation',
    overallScore: 82,
    skills: [
      SkillCard(
        title: 'Tone & Delivery',
        score: 88,
        tags: ['Confident', 'Natural'],
      ),
      SkillCard(
        title: 'Speech Clarity',
        score: 79,
        tags: ['Clear', 'Paced'],
      ),
      SkillCard(
        title: 'Content Strategy',
        score: 74,
        tags: ['Structured', 'Focused'],
      ),
    ],
    insights: [
      'You maintained a calm and assertive tone throughout the negotiation, which is a strong signal of confidence to the other party.',
      'Your arguments were well-structured and backed by relevant context. Try to tie your asks more directly to business outcomes.',
      'Pausing strategically before responding showed great composure. Continue leveraging silence as a negotiation tool.',
    ],
    improvements: [
      'Speak slower during key points to let them land',
      'Maintain consistent volume — avoid trailing off at sentence ends',
      'Ask more clarifying questions to understand the other side',
    ],
  );
}
