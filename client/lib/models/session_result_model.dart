import 'package:communiq/models/feedback_config.dart';

// ─── Opening Response ──────────────────────────────────────────────────────────

/// Maps the response from POST /sessions/opening (AI speaks first, no user audio).
class OpeningResult {
  final String aiReply;
  final String aiAudioBase64;

  /// True when Node has `LIVEKIT_ENABLED=true` — Flutter joins the LiveKit room after the opening clip.
  final bool liveVoiceEnabled;

  const OpeningResult({
    required this.aiReply,
    required this.aiAudioBase64,
    this.liveVoiceEnabled = false,
  });

  factory OpeningResult.fromJson(Map<String, dynamic> json) {
    return OpeningResult(
      aiReply: json['aiReply'] as String? ?? '',
      aiAudioBase64: json['aiAudioBase64'] as String? ?? '',
      liveVoiceEnabled: json['liveVoiceEnabled'] as bool? ?? false,
    );
  }
}

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
  int get pronunciation => scores['pronunciation'] ?? 0;

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
        'You used $fillerWordCount filler word${fillerWordCount == 1 ? '' : 's'}'
        '${fillerWords.isNotEmpty ? ' (${fillerWords.take(4).join(', ')})' : ''}'
        ' — practice pausing instead of filling silence.',
      if (fillerWordCount == 0)
        'Great job — no filler words detected. Your speech was clean and direct.',
      if (pronunciation > 0 && pronunciation < 65)
        'Your pronunciation score was $pronunciation% — focus on clear articulation '
        'and slowing down at key moments so every word lands clearly.',
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
        if (pronunciation > 0)
          SkillCard(
            title: 'Pronunciation',
            score: pronunciation,
            tags: _tagsForScore(pronunciation),
          ),
      ],
      insights: insights,
      improvements: improvements,
    );
  }
}

/// One event from the streamed turn endpoint (`POST /sessions/turn/stream`).
///
/// The stream is newline-delimited JSON in a fixed order: the transcript, then
/// one entry per synthesised sentence, then a terminator. An [error] may
/// replace the tail — once streaming has begun the HTTP status is already
/// committed, so a mid-stream failure can only arrive as data.
sealed class TurnEvent {
  const TurnEvent();

  factory TurnEvent.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'transcript':
        return TurnTranscript(
          userTranscript: json['userTranscript'] as String? ?? '',
          aiReply: json['aiReply'] as String? ?? '',
          turnCount: (json['turnCount'] as num?)?.toInt() ?? 0,
        );
      case 'audio':
        return TurnAudioChunk(
          index: (json['index'] as num?)?.toInt() ?? 0,
          audioBase64: json['audioBase64'] as String? ?? '',
        );
      case 'done':
        return const TurnDone();
      default:
        return TurnStreamError(
          json['detail'] as String? ?? 'The turn failed part-way through.',
        );
    }
  }
}

/// What the user said and what the AI will say. Arrives before any audio, so
/// both can be shown while the voice is still being synthesised.
class TurnTranscript extends TurnEvent {
  const TurnTranscript({
    required this.userTranscript,
    required this.aiReply,
    required this.turnCount,
  });

  final String userTranscript;
  final String aiReply;
  final int turnCount;
}

/// One sentence of synthesised audio. [index] is the playback order, which is
/// also the order these arrive in — audio cannot be played out of sequence.
class TurnAudioChunk extends TurnEvent {
  const TurnAudioChunk({required this.index, required this.audioBase64});

  final int index;
  final String audioBase64;
}

/// Every sentence has been sent.
class TurnDone extends TurnEvent {
  const TurnDone();
}

/// The turn failed after streaming had already started.
class TurnStreamError extends TurnEvent {
  const TurnStreamError(this.detail);

  final String detail;
}
