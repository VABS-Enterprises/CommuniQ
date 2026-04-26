import 'package:flutter/foundation.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/demo_evaluation_result.dart';

class LearningService {
  LearningService._();

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
