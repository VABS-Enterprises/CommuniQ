import 'package:communiq/core/data/static_levels.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelService {
  LevelService._();
  static final LevelService instance = LevelService._();

  List<CommuniqLevel>? _cachedLevels;

  Future<List<CommuniqLevel>> fetchLevels() async {
    if (_cachedLevels != null) return _cachedLevels!;

    try {
      debugPrint('[LevelService] fetchLevels (static) →');
      _cachedLevels = StaticLevels.allLevels;
      return _cachedLevels!;
    } catch (e) {
      debugPrint('[LevelService] Static fetchLevels error: $e');
      rethrow;
    }
  }

  void clearCache() {
    _cachedLevels = null;
  }

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
      final keys = prefs.getKeys();
      for (final key in keys) {
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
