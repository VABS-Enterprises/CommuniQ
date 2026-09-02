import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/contest_models.dart';

/// Talks to the contest endpoints.
///
/// These routes — POST /contest/submit, GET /contest/history,
/// GET /contest/leaderboard — were fully implemented server-side (they wire up
/// ai-server's /evaluate/contest scorer) but nothing in the app ever called
/// them. The Contest tab instead ran on an in-memory mock that fabricated a
/// rank, a history and a score. This service replaces that mock.
class ContestService {
  ContestService._();
  static final ContestService instance = ContestService._();

  Dio get _dio => ApiService.instance.dio;

  /// Server-enforced bounds (contestController.js). Mirrored here so the UI
  /// can disable the submit button rather than round-trip to a 400.
  static const int minAnswerLength = 10;
  static const int maxAnswerLength = 6000;

  /// Submits an answer for scoring. Costs an LLM call server-side and is rate
  /// limited to 10/min per user.
  Future<ContestResult> submit({
    required ContestType type,
    required String answer,
    String? motion,
    String? position,
  }) async {
    try {
      final res = await _dio.post('/contest/submit', data: {
        'contestType': type.id,
        'userAnswer': answer.trim(),
        if (motion != null && motion.isNotEmpty) 'motion': motion,
        if (position != null && position.isNotEmpty) 'position': position,
      });
      final result = ContestResult.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
      debugPrint('[ContestService] submit ✓ score=${result.overallScore} '
          'xp=${result.xpAwarded}');
      return result;
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not score your answer.'));
    }
  }

  Future<List<ContestAttempt>> history({int limit = 20}) async {
    try {
      final res = await _dio.get(
        '/contest/history',
        queryParameters: {'limit': limit},
      );
      final raw = (res.data as Map?)?['attempts'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => ContestAttempt.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not load your contest history.'));
    }
  }

  /// Contest standings. Pass [type] to scope to one format.
  Future<List<ContestRank>> leaderboard({
    ContestType? type,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get('/contest/leaderboard', queryParameters: {
        if (type != null) 'contestType': type.id,
        'limit': limit,
      });
      final raw = (res.data as Map?)?['leaderboard'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map((e) => ContestRank.fromJson(
                e.value.cast<String, dynamic>(),
                e.key,
              ))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not load the leaderboard.'));
    }
  }

  /// Node wraps errors as `{error}`; prefer that over Dio's generic text.
  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
    debugPrint('[ContestService] ${e.type} ${e.message}');
    return fallback;
  }
}
