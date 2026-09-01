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
  /// index used when calling [LearningService.submitAnswer].
  final Map<int, Map<int, bool>> levelProgress;

  const LearningProgress({
    required this.coins,
    required this.completedLevelIds,
    required this.levelProgress,
  });

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

    return LearningProgress(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      completedLevelIds: completedLevelIds,
      levelProgress: levelProgress,
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

  const LearningAnswerResult({
    required this.correct,
    required this.coinsAwarded,
    required this.totalCoins,
    required this.attemptNumber,
  });

  factory LearningAnswerResult.fromJson(Map<String, dynamic> json) {
    return LearningAnswerResult(
      correct: json['correct'] as bool? ?? false,
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
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

  /// POST /learning/levels/:levelId/complete — the server verifies
  /// server-side that every MCQ step for the level was answered correctly
  /// before marking it complete. May reject with a 400 (e.g. if called out
  /// of order); callers should catch and handle that gracefully rather than
  /// crash.
  static Future<List<int>> completeLevel(int levelId) async {
    debugPrint('[LearningService] completeLevel → levelId=$levelId');
    final response = await ApiService.post(
      '${ApiConstants.learningLevelsBase}/$levelId/complete',
    );
    final raw = response['completedLevelIds'] as List? ?? [];
    final ids = raw
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
    debugPrint('[LearningService] completeLevel ✓ completed=${ids.length}');
    return ids;
  }

  /// Submits the user's personal response to the learning module evaluation
  /// endpoint and returns structured AI feedback.
  ///
  /// [question]           — the response prompt shown to the user
  /// [userResponse]       — the text the user typed or spoke
  /// [topic]              — journey/topic name (e.g. "Assertive Communication")
  /// [difficulty]         — 'beginner' | 'intermediate' | 'advanced'
  /// [expectedKeyPoints]  — optional list of expected ideas in a good answer
  static Future<DemoEvaluationResult> evaluateLearningResponse({
    required String question,
    required String userResponse,
    required String topic,
    String difficulty = 'beginner',
    List<String> expectedKeyPoints = const [],
  }) async {
    debugPrint('[LearningService] Evaluating response (${userResponse.length} chars) topic=$topic');
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
    debugPrint('[LearningService] Evaluation complete — overall=${result.overallScore}');
    return result;
  }
}
