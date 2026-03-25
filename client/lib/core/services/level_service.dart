import 'package:communiq/core/data/static_levels.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:flutter/foundation.dart';

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
}
