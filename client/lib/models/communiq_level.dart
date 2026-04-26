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

  /// Returns the standardized path for the premium level illustration.
  /// For now, we reuse the existing V2 circular assets deterministically based on ID
  /// so that all 150 levels have a premium illustration.
  String get imageAsset {
    final images = [
      'assets/images/scenarios/introduce_yourself.png',
      'assets/images/scenarios/job_interview_v2.png',
      'assets/images/scenarios/negotiation_v2.png',
      'assets/images/scenarios/technical_solving.png',
      'assets/images/scenarios/sales_pitch.png',
      'assets/images/scenarios/complex_concept.png',
      'assets/images/scenarios/difficult_client_v2.png',
      'assets/images/scenarios/gd_ai.png',
      'assets/images/scenarios/salary_negotiation.png',
      'assets/images/scenarios/strengths_weaknesses.png',
      'assets/images/scenarios/why_hire_you.png',
    ];
    
    // Use the exact image if title matches roughly
    final t = title.toLowerCase();
    if (t.contains('interview')) return 'assets/images/scenarios/job_interview_v2.png';
    if (t.contains('negotiat')) return 'assets/images/scenarios/negotiation_v2.png';
    if (t.contains('solving') || t.contains('technical')) return 'assets/images/scenarios/technical_solving.png';
    if (t.contains('pitch') || t.contains('sell')) return 'assets/images/scenarios/sales_pitch.png';
    if (t.contains('introduce')) return 'assets/images/scenarios/introduce_yourself.png';
    if (t.contains('concept') || t.contains('explain')) return 'assets/images/scenarios/complex_concept.png';
    
    // Otherwise deterministically cycle through the premium images
    final index = id % images.length;
    return images[index];
  }

  /// Icon emoji representing the category — used in UI as a fallback.
  String get categoryEmoji {
    // Categories are replaced by journeys, so we can return a default or map from journey title
    return '✨';
  }
}
