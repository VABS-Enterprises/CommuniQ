/// A single multiple-choice question step.
class CommuniqMCQ {
  final int step;
  final String question;
  final String correctOption;
  final List<String> incorrectOptions;
  final String correctFeedback;
  final String incorrectFeedback;

  const CommuniqMCQ({
    required this.step,
    required this.question,
    required this.correctOption,
    required this.incorrectOptions,
    required this.correctFeedback,
    required this.incorrectFeedback,
  });

  factory CommuniqMCQ.fromJson(Map<String, dynamic> json) {
    return CommuniqMCQ(
      step: json['step'] as int? ?? 1,
      question: json['question'] as String? ?? '',
      correctOption: json['correct_option'] as String? ?? '',
      incorrectOptions: List<String>.from(json['incorrect_options'] ?? []),
      correctFeedback: json['correct_feedback'] as String? ?? 'Perfect!',
      incorrectFeedback: json['incorrect_feedback'] as String? ?? 'Try again!',
    );
  }
}

/// A single learning scenario in the CommuniQ journey.
class CommuniqLevel {
  final int id;
  final int journeyId;
  final String journeyTitle;
  final String title;
  final String scenario;
  final List<CommuniqMCQ> mcqs;
  final String responsePrompt;
  final String responseSuccessFeedback;

  const CommuniqLevel({
    required this.id,
    required this.journeyId,
    required this.journeyTitle,
    required this.title,
    required this.scenario,
    required this.mcqs,
    required this.responsePrompt,
    required this.responseSuccessFeedback,
  });

  // Compatibility getters for single-MCQ logic
  String get mcqQuestion => mcqs.isNotEmpty ? mcqs.first.question : '';
  String get mcqCorrectOption => mcqs.isNotEmpty ? mcqs.first.correctOption : '';
  List<String> get mcqIncorrectOptions => mcqs.isNotEmpty ? mcqs.first.incorrectOptions : [];
  String get mcqCorrectFeedback => mcqs.isNotEmpty ? mcqs.first.correctFeedback : '';
  String get mcqIncorrectFeedback => mcqs.isNotEmpty ? mcqs.first.incorrectFeedback : '';

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>? ?? {};
    final mcqsJson = json['mcqs'] as List<dynamic>? ?? [];
    
    // Support legacy 'mcq' field if present
    List<CommuniqMCQ> mcqsList = mcqsJson.map((m) => CommuniqMCQ.fromJson(m)).toList();
    if (mcqsList.isEmpty && json['mcq'] != null) {
      mcqsList.add(CommuniqMCQ.fromJson(json['mcq']));
    }

    return CommuniqLevel(
      id: json['id'] as int,
      journeyId: json['journey_id'] as int? ?? 1,
      journeyTitle: json['journey_title'] as String? ?? '',
      title: json['title'] as String,
      scenario: json['scenario'] as String,
      mcqs: mcqsList,
      responsePrompt: response['prompt'] as String? ?? (json['response_prompt'] ?? ''),
      responseSuccessFeedback: response['success_feedback'] as String? ?? (json['response_success_feedback'] ?? 'Great job!'),
    );
  }

  /// Returns the standardized path for the premium level illustration.
  /// Mapped to the Hub it belongs to (every 15 levels).
  String get imageAsset {
    final images = [
      'assets/images/scenarios/introduce_yourself.png',
      'assets/images/scenarios/job_interview_v2.png',
      'assets/images/scenarios/negotiation_v2.png',
      'assets/images/scenarios/technical_solving.png',
      'assets/images/scenarios/sales_pitch.png',
      'assets/images/scenarios/complex_concept.png',
      'assets/images/scenarios/difficult_client.png',
      'assets/images/scenarios/gd_ai.png',
      'assets/images/scenarios/salary_negotiation.png',
      'assets/images/scenarios/strengths_weaknesses.png',
      'assets/images/scenarios/why_hire_you.png',
      'assets/images/scenarios/cold_call.png',
    ];
    
    // Use scenario ID to pick unique illustration (consistent with map)
    return images[(id - 1) % images.length];
  }

  String get categoryEmoji => '✨';
}
