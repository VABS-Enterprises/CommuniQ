/// A single multiple-choice question step.
///
/// Deliberately carries no notion of which option is correct. The server
/// strips the answer key from `GET /levels` and grades submissions in
/// `POST /learning/answer`, returning both the verdict and the feedback text —
/// so a decompiled APK reveals nothing.
class CommuniqMCQ {
  /// The server's own step number. Not the list index — always send this back
  /// when grading, since the two are only incidentally equal.
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

/// The short lesson shown before the questions.
///
/// The quiz used to open cold, so the only way through was to guess between
/// four near-identical options. Every level now teaches the idea first and
/// then tests it.
class CommuniqTeaching {
  /// One sentence: the principle this level is about.
  final String idea;

  /// Two to four concrete rules that follow from [idea].
  final List<String> points;

  const CommuniqTeaching({required this.idea, required this.points});

  factory CommuniqTeaching.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];
    return CommuniqTeaching(
      idea: json['idea'] as String? ?? '',
      points: raw is List ? raw.map((e) => '$e').toList() : const [],
    );
  }

  bool get isEmpty => idea.isEmpty && points.isEmpty;
}

/// One journey — a themed group of five consecutive levels.
class CommuniqJourney {
  final int id;
  final String title;
  final String subtitle;
  final String emoji;
  final int startLevel;
  final int endLevel;

  const CommuniqJourney({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.startLevel,
    required this.endLevel,
  });

  factory CommuniqJourney.fromJson(Map<String, dynamic> json) {
    return CommuniqJourney(
      id: (json['id'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📘',
      startLevel: (json['start_level'] as num?)?.toInt() ?? 1,
      endLevel: (json['end_level'] as num?)?.toInt() ?? 1,
    );
  }

  bool contains(int levelId) => levelId >= startLevel && levelId <= endLevel;
}

/// A single learning scenario in the CommuniQ journey.
class CommuniqLevel {
  final int id;
  final int journeyId;
  final String journeyTitle;
  final String title;

  /// Shown on the level node and the intro card.
  final String emoji;

  /// The one-word skill this level trains, e.g. "Boundaries".
  final String skill;

  /// 'beginner' | 'intermediate' | 'advanced'.
  final String difficulty;

  /// One line describing what the learner will be able to do afterwards.
  final String goal;

  final String scenario;
  final CommuniqTeaching teaching;
  final List<CommuniqMCQ> mcqs;
  final String responsePrompt;
  final String responseSuccessFeedback;

  const CommuniqLevel({
    required this.id,
    required this.journeyId,
    required this.journeyTitle,
    required this.title,
    required this.emoji,
    required this.skill,
    required this.difficulty,
    required this.goal,
    required this.scenario,
    required this.teaching,
    required this.mcqs,
    required this.responsePrompt,
    required this.responseSuccessFeedback,
  });

  /// Total gradable steps: every MCQ, plus the written response.
  int get totalSteps => mcqs.length + 1;

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>? ?? {};
    final mcqsJson = json['mcqs'] as List<dynamic>? ?? [];

    return CommuniqLevel(
      id: (json['id'] as num).toInt(),
      journeyId: (json['journey_id'] as num?)?.toInt() ?? 1,
      journeyTitle: json['journey_title'] as String? ?? '',
      title: json['title'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '💬',
      skill: json['skill'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'beginner',
      goal: json['goal'] as String? ?? '',
      scenario: json['scenario'] as String? ?? '',
      teaching: CommuniqTeaching.fromJson(
        json['teaching'] as Map<String, dynamic>? ?? const {},
      ),
      mcqs: mcqsJson
          .whereType<Map<String, dynamic>>()
          .map(CommuniqMCQ.fromJson)
          .toList(),
      responsePrompt: response['prompt'] as String? ?? '',
      responseSuccessFeedback:
          response['success_feedback'] as String? ?? 'Nicely done.',
    );
  }
}
