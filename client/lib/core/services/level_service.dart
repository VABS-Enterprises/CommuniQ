import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/communiq_level.dart';

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

  List<CommuniqLevel>? _cachedLevels;

  Dio get _dio => ApiService.instance.dio;

  Future<List<CommuniqLevel>> fetchLevels() async {
    if (_cachedLevels != null) return _cachedLevels!;

    try {
      final res = await _dio.get(ApiConstants.levels);
      final data = res.data;

      final rawLevels = data is Map<String, dynamic>
          ? data['levels']
          : (data is List ? data : null);

      if (rawLevels is! List) {
        throw Exception('Unexpected /levels response shape');
      }

      _cachedLevels = rawLevels
          .whereType<Map<String, dynamic>>()
          .map(CommuniqLevel.fromJson)
          .toList();

      debugPrint('[LevelService] fetchLevels ✓ ${_cachedLevels!.length} levels');
      return _cachedLevels!;
    } on DioException catch (e) {
      debugPrint('[LevelService] fetchLevels ✗ ${e.message}');
      throw Exception('Could not load lessons. Check your connection.');
    } catch (e) {
      debugPrint('[LevelService] fetchLevels ✗ $e');
      rethrow;
    }
  }

  void clearCache() => _cachedLevels = null;

  /// Clears all learning progress from SharedPreferences.
  ///
  /// Must cover every cache key learning_view.dart writes, or a stale value
  /// survives sign-out and can flash on the next account signed into this
  /// device (e.g. a previous user's coin total) until the first server
  /// refresh completes. `total_coins_cache` doesn't match 'level_*' or
  /// 'completed_level_ids' so it needs its own explicit check.
  Future<void> clearProgress() async {
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
