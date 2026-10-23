import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disk store for the last successful response of every read-only API call,
/// so a launch with no connection still has data to show.
///
/// [ProfileCacheService] already did this for the profile alone. Everything
/// else — the curriculum, learning progress, session and contest history,
/// the leaderboard — only ever lived in memory, so an offline restart showed
/// empty states and error banners even though the data had been fetched
/// minutes earlier. This is the same idea applied to every GET, keyed by URL,
/// and wired in as a Dio interceptor rather than repeated per service.
///
/// Entries are namespaced by Firebase uid: the next account signed into this
/// device must never be served the previous one's cached responses.
class OfflineCacheService {
  OfflineCacheService._();

  static const _prefix = 'offline_cache_v1:';

  static String _key(String uid, String url) => '$_prefix$uid:$url';

  /// Stores [body] as the cached response for [url]. Silently does nothing if
  /// the body isn't JSON-encodable — a cache miss is always survivable.
  static Future<void> write(String uid, String url, Object? body) async {
    if (body is! Map && body is! List) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(uid, url), jsonEncode(body));
    } catch (e) {
      debugPrint('[OfflineCache] write failed for $url: $e');
    }
  }

  /// Returns the decoded cached body for [url], or null if nothing is stored.
  static Future<Object?> read(String uid, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid, url));
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('[OfflineCache] read failed for $url: $e');
      return null;
    }
  }

  /// Drops every cached response. Called on sign-out.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('[OfflineCache] clear failed: $e');
    }
  }
}
