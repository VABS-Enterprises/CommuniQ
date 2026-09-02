import 'package:flutter/foundation.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/demo_evaluation_result.dart';

/// Server-authoritative learning-module progress snapshot returned by
/// `GET /learning/progress`. This is the source of truth for coins,
/// completed levels, and per-level MCQ step completion — the client must
/// not derive these values locally.
class LearningProgress {
  final int coins;
  final Set<int> completedLevelIds;

  /// levelId -> (step -> answered correctly). Keyed by the same `step`
  /// value used when calling [LearningService.submitAnswer].
  final Map<int, Map<int, bool>> levelProgress;

  /// levelId -> coins earned in that level.
  final Map<int, int> levelCoins;

  /// levelId -> the AI score awarded for that level's written response.
  final Map<int, int> responseScores;

  /// levelId -> how many MCQ steps that level has, so a partially finished
  /// level can render "2 of 4" without the client holding the curriculum.
  final Map<int, int> stepTotals;

  const LearningProgress({
    required this.coins,
    required this.completedLevelIds,
    required this.levelProgress,
    this.levelCoins = const {},
    this.responseScores = const {},
    this.stepTotals = const {},
  });

  const LearningProgress.empty()
      : coins = 0,
        completedLevelIds = const {},
        levelProgress = const {},
        levelCoins = const {},
        responseScores = const {},
        stepTotals = const {};

  /// How many MCQ steps of [levelId] have been answered correctly.
  int stepsSolved(int levelId) =>
      (levelProgress[levelId] ?? const {}).values.where((v) => v).length;

  static Map<int, int> _intMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, int>{};
    raw.forEach((k, v) {
      final key = int.tryParse(k.toString());
      final value = v is num ? v.toInt() : int.tryParse(v.toString());
      if (key != null && value != null) out[key] = value;
    });
    return out;
  }

  factory LearningProgress.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['completedLevelIds'] as List? ?? [];
    final completedLevelIds = rawCompleted
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toSet();

    final rawProgress = json['levelProgress'] as Map<String, dynamic>? ?? {};
    final levelProgress = <int, Map<int, bool>>{};
    rawProgress.forEach((levelIdStr, steps) {
      final levelId = int.tryParse(levelIdStr);
      if (levelId == null || steps is! Map) return;
      final stepMap = <int, bool>{};
      steps.forEach((stepStr, done) {
        final step = int.tryParse(stepStr.toString());
        if (step != null) stepMap[step] = done == true;
      });
      levelProgress[levelId] = stepMap;
    });

    // responses is { levelId: { score, coins } } — only the score is needed here.
    final responseScores = <int, int>{};
    final rawResponses = json['responses'];
    if (rawResponses is Map) {
      rawResponses.forEach((k, v) {
        final levelId = int.tryParse(k.toString());
        if (levelId == null || v is! Map) return;
        final score = v['score'];
        if (score is num) responseScores[levelId] = score.toInt();
      });
    }

    return LearningProgress(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      completedLevelIds: completedLevelIds,
      levelProgress: levelProgress,
      levelCoins: _intMap(json['levelCoins']),
      responseScores: responseScores,
      stepTotals: _intMap(json['stepTotals']),
    );
  }
}

/// Result of server-side grading for a single MCQ answer, returned by
/// `POST /learning/answer`. [attemptNumber] is tracked by the server —
/// the client never sends or locally computes an attempt count.
class LearningAnswerResult {
  final bool correct;
  final int coinsAwarded;
  final int totalCoins;
  final int attemptNumber;

  /// Server-supplied feedback for this outcome. The client no longer holds
  /// the per-outcome feedback strings — carrying both would have revealed the
  /// answer as surely as the answer key itself.
  final String feedback;

  /// The correct option text. Present when the step is solved, and — once
  /// the user has missed it twice — when it is not, so the app can stop
  /// testing and start teaching. Null while the answer is still worth
  /// guessing at.
  final String? correctOption;

  /// True when [correctOption] arrived because the user ran out of attempts
  /// rather than because they got it right.
  final bool revealed;

  /// Live per-level progress, straight from the server's own record.
  final int stepsSolved;
  final int totalSteps;

  const LearningAnswerResult({
    required this.correct,
    required this.coinsAwarded,
    required this.totalCoins,
    required this.attemptNumber,
    required this.feedback,
    this.correctOption,
    this.revealed = false,
    this.stepsSolved = 0,
    this.totalSteps = 0,
  });

  factory LearningAnswerResult.fromJson(Map<String, dynamic> json) {
    final correct = json['correct'] as bool? ?? false;
    return LearningAnswerResult(
      correct: correct,
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
      feedback: json['feedback'] as String? ??
          (correct ? 'Correct!' : 'Not quite — try again.'),
      correctOption: json['correctOption'] as String?,
      revealed: json['revealed'] as bool? ?? false,
      stepsSolved: (json['stepsSolved'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of `POST /learning/levels/:id/complete`.
class LevelCompletionResult {
  final List<int> completedLevelIds;
  final int coinsAwarded;
  final int totalCoins;
  final int levelCoins;

  /// True when the level had already been completed before this call, so no
  /// coins were awarded for it a second time.
  final bool alreadyComplete;

  const LevelCompletionResult({
    required this.completedLevelIds,
    required this.coinsAwarded,
    required this.totalCoins,
    required this.levelCoins,
    required this.alreadyComplete,
  });

  factory LevelCompletionResult.fromJson(Map<String, dynamic> json) {
    final raw = json['completedLevelIds'] as List? ?? [];
    return LevelCompletionResult(
      completedLevelIds: raw
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()
          .toList(),
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
      levelCoins: (json['levelCoins'] as num?)?.toInt() ?? 0,
      alreadyComplete: json['alreadyComplete'] as bool? ?? false,
    );
  }
}

class LearningService {
  LearningService._();

  /// GET /learning/progress — fetches the authoritative coin total,
  /// completed level ids, and per-level MCQ step completion. Requires auth;
  /// the Firebase Bearer token is attached automatically by [ApiService].
  static Future<LearningProgress> getProgress() async {
    debugPrint('[LearningService] getProgress →');
    final response = await ApiService.get(ApiConstants.learningProgress);
    final progress = LearningProgress.fromJson(response);
    debugPrint('[LearningService] getProgress ✓ coins=${progress.coins} '
        'completed=${progress.completedLevelIds.length}');
    return progress;
  }

  /// POST /learning/answer — submits the exact option text the user tapped
  /// for server-side grading. The server tracks the attempt count and
  /// computes the coin award; callers must drive UI/coin state from the
  /// returned [LearningAnswerResult], not from any local answer key.
  static Future<LearningAnswerResult> submitAnswer({
    required int levelId,
    required int step,
    required String selectedOption,
  }) async {
    debugPrint(
        '[LearningService] submitAnswer → levelId=$levelId step=$step');
    final response = await ApiService.post(
      ApiConstants.learningAnswer,
      body: {
        'levelId': levelId,
        'step': step,
        'selectedOption': selectedOption,
      },
    );
    final result = LearningAnswerResult.fromJson(response);
    debugPrint('[LearningService] submitAnswer ✓ correct=${result.correct} '
        'coinsAwarded=${result.coinsAwarded} totalCoins=${result.totalCoins}');
    return result;
  }

  /// POST /learning/levels/:levelId/complete — the server verifies that every
  /// MCQ step for the level was answered correctly before marking it
  /// complete, then awards the written-response coins and the completion
  /// bonus. May reject with a 400 (e.g. if called out of order); callers
  /// should catch and handle that gracefully rather than crash.
  ///
  /// [responseScore] is the AI evaluation score for the written response.
  /// The coins for it are computed and persisted server-side — the client
  /// must not add them to any displayed total itself.
  static Future<LevelCompletionResult> completeLevel(
    int levelId, {
    int? responseScore,
  }) async {
    debugPrint('[LearningService] completeLevel → levelId=$levelId '
        'responseScore=$responseScore');
    final response = await ApiService.post(
      '${ApiConstants.learningLevelsBase}/$levelId/complete',
      body: {if (responseScore != null) 'responseScore': responseScore},
    );
    final result = LevelCompletionResult.fromJson(response);
    debugPrint('[LearningService] completeLevel ✓ '
        'coinsAwarded=${result.coinsAwarded} total=${result.totalCoins}');
    return result;
  }

  /// Submits the user's personal response to the learning module evaluation
  /// endpoint and returns structured AI feedback.
  ///
  /// [question]           — the response prompt shown to the user
  /// [userResponse]       — the text the user typed or spoke
  /// [topic]              — journey/topic name (e.g. "Hard Conversations")
  /// [difficulty]         — 'beginner' | 'intermediate' | 'advanced'
  /// [expectedKeyPoints]  — optional list of expected ideas in a good answer
  static Future<DemoEvaluationResult> evaluateLearningResponse({
    required String question,
    required String userResponse,
    required String topic,
    String difficulty = 'beginner',
    List<String> expectedKeyPoints = const [],
  }) async {
    debugPrint('[LearningService] Evaluating response '
        '(${userResponse.length} chars) topic=$topic');
    final response = await ApiService.post(
      ApiConstants.levelsEvaluate,
      body: {
        'question': question,
        'userResponse': userResponse,
        'topic': topic,
        'difficulty': difficulty,
        'expectedKeyPoints': expectedKeyPoints,
      },
    );
    final result = DemoEvaluationResult.fromJson(response);
    debugPrint(
        '[LearningService] Evaluation complete — overall=${result.overallScore}');
    return result;
  }
}
