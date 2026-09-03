import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/models/communiq_level.dart';

/// The curriculum, as served by `GET /levels`.
class Curriculum {
  final List<CommuniqLevel> levels;
  final List<CommuniqJourney> journeys;

  const Curriculum({required this.levels, required this.journeys});

  /// The journey a level belongs to, or null if the data disagrees with
  /// itself. Matched on the declared level range rather than `journey_id`,
  /// which is the field most likely to be wrong after a content edit.
  CommuniqJourney? journeyFor(int levelId) {
    for (final j in journeys) {
      if (j.contains(levelId)) return j;
    }
    return null;
  }
}

/// Loads the learning curriculum from the server.
///
/// The levels used to be a 330-line hardcoded Dart file that included every
/// `correctOption` — the full MCQ answer key, shipped inside the APK, even
/// though grading is server-authoritative. That file is gone: `GET /levels`
/// now serves questions and options with the key stripped out, and
/// `POST /learning/answer` decides correctness.
class LevelService {
  LevelService._();
  static final LevelService instance = LevelService._();

  Curriculum? _cached;

  Dio get _dio => ApiService.instance.dio;

  Future<Curriculum> fetchCurriculum() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final res = await _dio.get(ApiConstants.levels);
      final data = res.data;

      final rawLevels = data is Map<String, dynamic>
          ? data['levels']
          : (data is List ? data : null);

      if (rawLevels is! List) {
        throw Exception('Unexpected /levels response shape');
      }

      final levels = rawLevels
          .whereType<Map<String, dynamic>>()
          .map(CommuniqLevel.fromJson)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final rawJourneys =
          data is Map<String, dynamic> ? data['journeys'] : null;
      final journeys = rawJourneys is List
          ? (rawJourneys
              .whereType<Map<String, dynamic>>()
              .map(CommuniqJourney.fromJson)
              .toList()
            ..sort((a, b) => a.startLevel.compareTo(b.startLevel)))
          : <CommuniqJourney>[];

      final curriculum = Curriculum(levels: levels, journeys: journeys);
      _cached = curriculum;
      debugPrint('[LevelService] fetchCurriculum ✓ ${levels.length} levels, '
          '${journeys.length} journeys');
      return curriculum;
    } on DioException catch (e) {
      debugPrint('[LevelService] fetchCurriculum ✗ ${e.message}');
      throw Exception('Could not load lessons. Check your connection.');
    } catch (e) {
      debugPrint('[LevelService] fetchCurriculum ✗ $e');
      rethrow;
    }
  }

  /// Convenience for callers that only need the level list.
  Future<List<CommuniqLevel>> fetchLevels() async =>
      (await fetchCurriculum()).levels;

  void clearCache() => _cached = null;

  /// Clears all learning progress held on this device.
  ///
  /// Must cover every cache key learning_view.dart writes, or a stale value
  /// survives sign-out and can flash on the next account signed into this
  /// device (e.g. a previous user's coin total) until the first server
  /// refresh completes. `total_coins_cache` doesn't match 'level_*' or
  /// 'completed_level_ids' so it needs its own explicit check.
  Future<void> clearProgress() async {
    // The in-memory snapshot is what the UI actually reads, so it has to go
    // too — clearing only SharedPreferences left the previous user's coins on
    // screen until the next successful fetch.
    LearningProgressStore.instance.clear();
    clearCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key == 'completed_level_ids' ||
            key == 'total_coins_cache' ||
            key.startsWith('level_')) {
          await prefs.remove(key);
        }
      }
      debugPrint('[LevelService] clearProgress ✓');
    } catch (e) {
      debugPrint('[LevelService] clearProgress failed: $e');
    }
  }
}
