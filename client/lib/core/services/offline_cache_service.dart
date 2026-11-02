import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-tier store for the responses of read-only API calls.
///
/// **Disk tier** — the last successful body of every GET, so a launch with no
/// (or a very weak) connection still has real data to show. Survives restarts.
///
/// **Memory tier** — bodies fetched in the last [freshFor]. The splash screen
/// warms these up, so the first screens after it render instantly instead of
/// repeating requests that finished a second earlier. Any write the app makes
/// (POST/PATCH/PUT/DELETE) drops the whole memory tier, because a write can
/// change what any GET returns — finishing a session changes the history, the
/// profile, the leaderboard. The disk tier is never served while the network
/// answers, so it can't hide a write either.
///
/// Everything is namespaced by Firebase uid: the next account signed into this
/// device must never be served the previous one's data.
class OfflineCacheService {
  OfflineCacheService._();

  static const _prefix = 'offline_cache_v1:';

  /// How long a just-fetched response is reused without asking the server.
  static const freshFor = Duration(seconds: 60);

  static String _key(String uid, String url) => '$_prefix$uid:$url';

  static final Map<String, ({DateTime at, Object body})> _memory = {};

  // ── Memory tier ───────────────────────────────────────────────────────────

  /// The body fetched for [url] within [freshFor], or null.
  static Object? fresh(String uid, String url) {
    final entry = _memory[_key(uid, url)];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > freshFor) {
      _memory.remove(_key(uid, url));
      return null;
    }
    return entry.body;
  }

  /// Forgets every in-memory response. Called after any write to the server.
  static void invalidateFresh() => _memory.clear();

  // ── Disk tier ─────────────────────────────────────────────────────────────

  /// Stores [body] as the cached response for [url] in both tiers. Silently
  /// does nothing if the body isn't JSON-encodable — a cache miss is always
  /// survivable.
  static Future<void> write(String uid, String url, Object? body) async {
    if (body == null || (body is! Map && body is! List)) return;
    _memory[_key(uid, url)] = (at: DateTime.now(), body: body);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(uid, url), jsonEncode(body));
    } catch (e) {
      debugPrint('[OfflineCache] write failed for $url: $e');
    }
  }

  /// Whether a disk copy exists for [url]. Cheap: SharedPreferences keeps its
  /// keys in memory after the first load.
  static Future<bool> has(String uid, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_key(uid, url));
    } catch (_) {
      return false;
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

  /// Drops every cached response, in both tiers. Called on sign-out.
  static Future<void> clear() async {
    _memory.clear();
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
