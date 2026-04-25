/// A single learning scenario in the CommuniQ journey.
/// Maps directly to one entry in communiq_levels_v3.json.
/// The internal _difficulty field from the JSON is intentionally
/// excluded — difficulty is never shown to the user in the UI.
class CommuniqLevel {
  final int id;
  final int journeyId;
  final String journeyTitle;
  final String title;
  final String scenario;

  // MCQ
  final String mcqQuestion;
  final String mcqCorrectOption;
  final List<String> mcqIncorrectOptions;
  final String mcqCorrectFeedback;
  final String mcqIncorrectFeedback;

  // Response
  final String responsePrompt;
  final String responseSuccessFeedback;

  const CommuniqLevel({
    required this.id,
    required this.journeyId,
    required this.journeyTitle,
    required this.title,
    required this.scenario,
    required this.mcqQuestion,
    required this.mcqCorrectOption,
    required this.mcqIncorrectOptions,
    required this.mcqCorrectFeedback,
    required this.mcqIncorrectFeedback,
    required this.responsePrompt,
    required this.responseSuccessFeedback,
  });

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    final mcq = json['mcq'] as Map<String, dynamic>? ?? {};
    final response = json['response'] as Map<String, dynamic>? ?? {};

    return CommuniqLevel(
      id: json['id'] as int,
      journeyId: json['journey_id'] as int? ?? 1,
      journeyTitle: json['journey_title'] as String? ?? '',
      title: json['title'] as String,
      scenario: json['scenario'] as String,
      mcqQuestion: mcq['question'] as String? ?? '',
      mcqCorrectOption: mcq['correct_option'] as String? ?? '',
      mcqIncorrectOptions: List<String>.from(mcq['incorrect_options'] ?? []),
      mcqCorrectFeedback: mcq['correct_feedback'] as String? ?? 'Perfect!',
      mcqIncorrectFeedback: mcq['incorrect_feedback'] as String? ?? 'Try again!',
      responsePrompt: response['prompt'] as String? ?? '',
      responseSuccessFeedback: response['success_feedback'] as String? ?? 'Great job!',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journey_id': journeyId,
      'journey_title': journeyTitle,
      'title': title,
      'scenario': scenario,
      'mcq': {
        'question': mcqQuestion,
        'correct_option': mcqCorrectOption,
        'incorrect_options': mcqIncorrectOptions,
        'correct_feedback': mcqCorrectFeedback,
        'incorrect_feedback': mcqIncorrectFeedback,
      },
      'response': {
        'prompt': responsePrompt,
        'success_feedback': responseSuccessFeedback,
      }
    };
  }

  /// XP reward per completed scenario (fixed for now, can be dynamic later)
  int get xpReward => 20;

  /// Icon emoji representing the category — used in UI nodes
  String get categoryEmoji {
    // Categories are replaced by journeys, so we can return a default or map from journey title
    return '✨';
  }
}
