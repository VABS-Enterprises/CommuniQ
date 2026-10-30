import 'package:flutter/foundation.dart';

import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';

/// One row of the real, server-authoritative XP leaderboard.
///
/// On `GET /leaderboard` [xp] is all-time XP. On `GET /leaderboard/weekly`
/// [xp] is the XP earned in the current ISO week and [totalXp] carries the
/// all-time figure. [level] always derives from all-time XP.
class LeaderboardEntry {
  final String uid;
  final String name;
  final int xp;

  /// All-time XP. Equal to [xp] on the all-time board; on the weekly board
  /// it falls back to [xp] only when the server omitted it.
  final int totalXp;
  final int level;
  final List<String> badges;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.xp,
    int? totalXp,
    required this.level,
    required this.badges,
  }) : totalXp = totalXp ?? xp;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final xp = _int(json['xp']) ?? 0;
    final rawBadges = json['badges'];
    return LeaderboardEntry(
      uid: json['uid'] is String ? json['uid'] as String : '',
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : 'Anonymous',
      xp: xp,
      totalXp: _int(json['totalXp']) ?? xp,
      level: _int(json['level']) ?? 1,
      badges: rawBadges is List
          ? rawBadges.map((b) => '$b').toList()
          : const [],
    );
  }

  static int? _int(dynamic v) =>
      v is num ? v.toInt() : (v is String ? num.tryParse(v)?.toInt() : null);
}

/// Orders overlapping loads so only the newest one may update the UI.
///
/// Toggling weekly/all-time (or a contest filter) quickly fires several
/// requests; without this, whichever response arrived *last* won — so a slow
/// all-time response could land under the "This week" tab.
class RequestSequencer {
  int _latest = 0;

  /// Starts a new request and returns its ticket. Every earlier ticket is
  /// now stale.
  int next() => ++_latest;

  /// Whether [ticket] is still the newest request.
  bool isCurrent(int ticket) => ticket == _latest;
}

/// Thin client for the two real leaderboard endpoints. Replaces the
/// previous static `kLeaderboard` mock (contest_state.dart) with live data.
class LeaderboardService {
  LeaderboardService._();

  static Future<List<LeaderboardEntry>> fetchAllTime() async {
    final response = await ApiService.get(ApiConstants.leaderboard);
    return parse(response);
  }

  static Future<List<LeaderboardEntry>> fetchWeekly() async {
    final response = await ApiService.get(ApiConstants.leaderboardWeekly);
    return parse(response);
  }

  @visibleForTesting
  static List<LeaderboardEntry> parse(Map<String, dynamic> response) {
    final raw = response['leaderboard'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => LeaderboardEntry.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}
