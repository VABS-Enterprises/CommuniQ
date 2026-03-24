import 'package:communiq/models/feedback_config.dart';

// ─── Turn Response ─────────────────────────────────────────────────────────────

/// Maps the response from POST /sessions/turn.
class TurnResult {
  final String userTranscript;
  final String aiReply;
  final String aiAudioBase64;
  final int turnCount;

  const TurnResult({
    required this.userTranscript,
    required this.aiReply,
    required this.aiAudioBase64,
    required this.turnCount,
  });

  factory TurnResult.fromJson(Map<String, dynamic> json) {
    return TurnResult(
      userTranscript: json['userTranscript'] as String? ?? '',
      aiReply: json['aiReply'] as String? ?? '',
      aiAudioBase64: json['aiAudioBase64'] as String? ?? '',
      turnCount: (json['turnCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Session End Response ──────────────────────────────────────────────────────

/// Maps the full response from POST /sessions/end.
class SessionEndResult {
  final SessionReport report;
  final int xpAwarded;
  final int newLevel;
  final bool leveledUp;
  final List<String> newBadges;
  final int newStreak;

  const SessionEndResult({
    required this.report,
    required this.xpAwarded,
    required this.newLevel,
    required this.leveledUp,
    required this.newBadges,
    required this.newStreak,
  });

  factory SessionEndResult.fromJson(Map<String, dynamic> json) {
    return SessionEndResult(
      report: SessionReport.fromJson(json['report'] as Map<String, dynamic>? ?? {}),
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      newLevel: (json['newLevel'] as num?)?.toInt() ?? 1,
      leveledUp: json['leveledUp'] as bool? ?? false,
      newBadges: (json['newBadges'] as List<dynamic>?)?.cast<String>() ?? [],
      newStreak: (json['newStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Session Report ────────────────────────────────────────────────────────────

/// Maps the `report` object inside the /sessions/end response.
class SessionReport {
  final Map<String, int> scores; // clarity, fluency, confidence, vocabulary, grammar (0–100)
  final int fillerWordCount;
  final List<String> fillerWords;
  final List<String> strengths;
  final List<String> improvements;
  final String? recommendedNextType;
  final String rawTranscript;

  const SessionReport({
    required this.scores,
    required this.fillerWordCount,
    required this.fillerWords,
    required this.strengths,
    required this.improvements,
    this.recommendedNextType,
    required this.rawTranscript,
  });

  factory SessionReport.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    final scores = rawScores.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );

    return SessionReport(
      scores: scores,
      fillerWordCount: (json['fillerWordCount'] as num?)?.toInt() ?? 0,
      fillerWords: (json['fillerWords'] as List<dynamic>?)?.cast<String>() ?? [],
      strengths: (json['strengths'] as List<dynamic>?)?.cast<String>() ?? [],
      improvements: (json['improvements'] as List<dynamic>?)?.cast<String>() ?? [],
      recommendedNextType: json['recommendedNextType'] as String?,
      rawTranscript: json['rawTranscript'] as String? ?? '',
    );
  }

  // ─── Derived helpers ────────────────────────────────────────────────────────

  int get clarity => scores['clarity'] ?? 0;
  int get fluency => scores['fluency'] ?? 0;
  int get confidence => scores['confidence'] ?? 0;
  int get vocabulary => scores['vocabulary'] ?? 0;
  int get grammar => scores['grammar'] ?? 0;

  int get overallScore {
    if (scores.isEmpty) return 0;
    final total = scores.values.fold<int>(0, (sum, v) => sum + v);
    return (total / scores.length).round();
  }

  List<String> _tagsForScore(int score) {
    if (score >= 80) return ['Excellent', 'Strong'];
    if (score >= 65) return ['Good', 'Solid'];
    return ['Developing', 'Growing'];
  }

  /// Converts this report into the FeedbackConfig expected by RoleplayFeedbackScreen.
  FeedbackConfig toFeedbackConfig(String scenarioTitle) {
    final clarityFluency = ((clarity + fluency) / 2).round();
    final vocabGrammar = ((vocabulary + grammar) / 2).round();

    final List<String> insights = [
      ...strengths,
      if (fillerWordCount > 0)
        'You used $fillerWordCount filler word${fillerWordCount == 1 ? '' : 's'} — '
            'practice pausing instead of filling silence.',
      if (fillerWordCount == 0)
        'Great job — no filler words detected. Your speech was clean and direct.',
    ];

    return FeedbackConfig(
      scenarioTitle: scenarioTitle,
      overallScore: overallScore,
      skills: [
        SkillCard(
          title: 'Clarity & Fluency',
          score: clarityFluency,
          tags: _tagsForScore(clarityFluency),
        ),
        SkillCard(
          title: 'Confidence',
          score: confidence,
          tags: _tagsForScore(confidence),
        ),
        SkillCard(
          title: 'Vocabulary & Grammar',
          score: vocabGrammar,
          tags: _tagsForScore(vocabGrammar),
        ),
      ],
      insights: insights.take(3).toList(),
      improvements: improvements.take(3).toList(),
    );
  }
}
