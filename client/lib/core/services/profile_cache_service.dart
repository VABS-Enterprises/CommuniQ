import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:communiq/models/user_profile.dart';

/// Persists the last successfully fetched [UserProfile] to secure,
/// encrypted-at-rest storage (Keychain on iOS, Keystore-backed
/// EncryptedSharedPreferences on Android) rather than plaintext
/// SharedPreferences, since the cached profile contains PII (name, email,
/// progress, and skill data).
///
/// This enables:
///   - Instant profile display on app open (zero-latency cache hit)
///   - Graceful offline degradation (show stale data, no error screen)
///   - Stale-while-revalidate: UI renders cache, network refresh updates silently
class ProfileCacheService {
  ProfileCacheService._();

  static const _key = 'profile_cache_v1';
  static const _storage = FlutterSecureStorage();

  /// Returns the last cached [UserProfile], or null if nothing is cached yet.
  static Future<UserProfile?> load() async {
    try {
      final raw = await _storage.read(key: _key);
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
      await _storage.write(key: _key, value: jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('[ProfileCache] save failed: $e');
    }
  }

  /// Removes the cached profile (e.g. on logout).
  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('[ProfileCache] clear failed: $e');
    }
  }
}
