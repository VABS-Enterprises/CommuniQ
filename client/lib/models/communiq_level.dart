/// A single multiple-choice question step.
///
/// Deliberately carries no notion of which option is correct. The server
/// strips the answer key from `GET /levels` and grades submissions in
/// `POST /learning/answer`, returning both the verdict and the feedback text —
/// so a decompiled APK reveals nothing.
class CommuniqMCQ {
  final int step;
  final String question;

  /// All options in server-provided order. The order is stable per level+step
  /// but carries no information about which one is correct.
  final List<String> options;

  const CommuniqMCQ({
    required this.step,
    required this.question,
    required this.options,
  });

  factory CommuniqMCQ.fromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    return CommuniqMCQ(
      step: (json['step'] as num?)?.toInt() ?? 1,
      question: json['question'] as String? ?? '',
      options: raw is List ? raw.map((e) => '$e').toList() : const [],
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

  String get mcqQuestion => mcqs.isNotEmpty ? mcqs.first.question : '';
  List<String> get mcqOptions => mcqs.isNotEmpty ? mcqs.first.options : const [];

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>? ?? {};
    final mcqsJson = json['mcqs'] as List<dynamic>? ?? [];
    
    // Support legacy 'mcq' field if present
    List<CommuniqMCQ> mcqsList = mcqsJson.map((m) => CommuniqMCQ.fromJson(m)).toList();
    if (mcqsList.isEmpty && json['mcq'] != null) {
      mcqsList.add(CommuniqMCQ.fromJson(json['mcq']));
    }

    return CommuniqLevel(
      id: (json['id'] as num).toInt(),
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
