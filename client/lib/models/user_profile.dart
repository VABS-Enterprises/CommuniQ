/// Skill stat returned inside `skillProgress` on the user document.
class SkillStat {
  final double avg;
  final int sessions;

  const SkillStat({required this.avg, required this.sessions});

  factory SkillStat.fromJson(Map<String, dynamic> json) => SkillStat(
        avg: (json['avg'] as num?)?.toDouble() ?? 0.0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      );
}

/// Maps the Firestore user document returned by GET /auth/me or GET /user/profile.
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

  /// skill → { avg: 0–100, sessions: count }
  final Map<String, SkillStat> skillProgress;

  /// Total completed sessions (populated separately from session history).
  final int sessionsCompleted;

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
    this.skillProgress = const {},
    this.sessionsCompleted = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawSkill =
        (json['skillProgress'] as Map<String, dynamic>?) ?? {};
    final skillMap = rawSkill.map(
      (k, v) => MapEntry(
        k,
        SkillStat.fromJson(v as Map<String, dynamic>? ?? {}),
      ),
    );

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
      skillProgress: skillMap,
      sessionsCompleted: (json['_sessionsCompleted'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        if (photoURL != null) 'photoURL': photoURL,
        'xp': xp,
        'level': level,
        'streak': streak,
        'badges': badges,
        'isPremium': isPremium,
        'skillProgress': skillProgress.map(
          (k, v) => MapEntry(k, {'avg': v.avg, 'sessions': v.sessions}),
        ),
        '_sessionsCompleted': sessionsCompleted,
      };

  /// Returns a copy with [sessionsCompleted] filled in.
  UserProfile copyWithSessions(int count) => UserProfile(
        uid: uid,
        email: email,
        name: name,
        photoURL: photoURL,
        xp: xp,
        level: level,
        streak: streak,
        badges: badges,
        isPremium: isPremium,
        skillProgress: skillProgress,
        sessionsCompleted: count,
      );

  // ── XP thresholds ──────────────────────────────────────────────────────────

  /// XP required to reach each level (mirrors xpService.js LEVEL_THRESHOLDS).
  static const List<int> levelThresholds = [0, 300, 700, 1200, 2000];

  /// Level labels.
  static const List<String> levelLabels = [
    'Starter',
    'Learner',
    'Practitioner',
    'Conversationalist',
    'Expert',
  ];

  String get levelLabel {
    final idx = (level - 1).clamp(0, levelLabels.length - 1);
    return levelLabels[idx];
  }

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

  /// Overall average across all 6 skills (0–100). Returns null if no data.
  double? get overallSkillAvg {
    if (skillProgress.isEmpty) return null;
    final total =
        skillProgress.values.fold<double>(0, (sum, s) => sum + s.avg);
    return total / skillProgress.length;
  }
}
