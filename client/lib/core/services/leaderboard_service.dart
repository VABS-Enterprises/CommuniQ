import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';

/// One row of the real, server-authoritative XP leaderboard
/// (GET /leaderboard, GET /leaderboard/weekly) — ranked by total XP.
class LeaderboardEntry {
  final String uid;
  final String name;
  final int xp;
  final int level;
  final List<String> badges;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.xp,
    required this.level,
    required this.badges,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      uid: json['uid'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Anonymous',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      badges: (json['badges'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Thin client for the two real leaderboard endpoints. Replaces the
/// previous static `kLeaderboard` mock (contest_state.dart) with live data.
class LeaderboardService {
  LeaderboardService._();

  static Future<List<LeaderboardEntry>> fetchAllTime() async {
    final response = await ApiService.get(ApiConstants.leaderboard);
    return _parse(response);
  }

  static Future<List<LeaderboardEntry>> fetchWeekly() async {
    final response = await ApiService.get(ApiConstants.leaderboardWeekly);
    return _parse(response);
  }

  static List<LeaderboardEntry> _parse(Map<String, dynamic> response) {
    final raw = response['leaderboard'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList();
  }
}
