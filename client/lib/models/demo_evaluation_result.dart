/// Result returned by POST /onboarding/demo.
/// Maps directly to the LearningEvaluateResponse from the AI server.
class DemoEvaluationResult {
  final Map<String, int> scores;   // accuracy, depth, clarity, examples
  final int overallScore;
  final List<String> strengths;    // exactly 2
  final List<String> improvements; // exactly 2
  final String feedback;

  const DemoEvaluationResult({
    required this.scores,
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.feedback,
  });

  factory DemoEvaluationResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    return DemoEvaluationResult(
      scores: rawScores.map((k, v) => MapEntry(k, (v as num).toInt())),
      overallScore: (json['overallScore'] as num?)?.toInt() ?? 0,
      strengths: List<String>.from(json['strengths'] as List? ?? []),
      improvements: List<String>.from(json['improvements'] as List? ?? []),
      feedback: json['feedback'] as String? ?? '',
    );
  }
}
