/// Maps the Firestore user document returned by GET /auth/me.
/// Field names match the Node userModel.js shape exactly.
class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String? photoURL;
  final int xp;
  final int level;
  final int streak;
  final List<String> badges;
  final bool isPremium;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    this.photoURL,
    required this.xp,
    required this.level,
    required this.streak,
    required this.badges,
    required this.isPremium,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photoURL: json['photoURL'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      badges: (json['badges'] as List<dynamic>?)?.cast<String>() ?? [],
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  /// XP required to reach each level (mirrors xpService.js LEVEL_THRESHOLDS).
  static const List<int> levelThresholds = [0, 300, 700, 1200, 2000];

  /// Progress within the current level as a fraction 0.0–1.0.
  double get xpProgress {
    final idx = (level - 1).clamp(0, levelThresholds.length - 1);
    final currentMin = levelThresholds[idx];
    final nextMin = idx + 1 < levelThresholds.length
        ? levelThresholds[idx + 1]
        : levelThresholds.last + 500;
    if (nextMin <= currentMin) return 1.0;
    return ((xp - currentMin) / (nextMin - currentMin)).clamp(0.0, 1.0);
  }

  /// XP still needed to reach the next level.
  int get xpToNextLevel {
    final idx = (level - 1).clamp(0, levelThresholds.length - 1);
    if (idx + 1 >= levelThresholds.length) return 0;
    final needed = levelThresholds[idx + 1] - xp;
    return needed < 0 ? 0 : needed;
  }

  /// Streak progress toward a 30-day goal, capped at 1.0.
  double get streakProgress => (streak / 30.0).clamp(0.0, 1.0);

  String get firstName {
    final first = name.split(' ').first;
    return first.isNotEmpty ? first : name;
  }
}
