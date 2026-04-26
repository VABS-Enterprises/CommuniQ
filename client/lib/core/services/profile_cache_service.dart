import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:communiq/models/user_profile.dart';

/// Persists the last successfully fetched [UserProfile] to SharedPreferences.
///
/// This enables:
///   - Instant profile display on app open (zero-latency cache hit)
///   - Graceful offline degradation (show stale data, no error screen)
///   - Stale-while-revalidate: UI renders cache, network refresh updates silently
class ProfileCacheService {
  ProfileCacheService._();

  static const _key = 'profile_cache_v1';

  /// Returns the last cached [UserProfile], or null if nothing is cached yet.
  static Future<UserProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProfileCache] load failed: $e');
      return null;
    }
  }

  /// Persists [profile] to disk. Called after every successful network fetch.
  static Future<void> save(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('[ProfileCache] save failed: $e');
    }
  }

  /// Removes the cached profile (e.g. on logout).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[ProfileCache] clear failed: $e');
    }
  }
}
