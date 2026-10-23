/// Skill stat returned inside `skillProgress` on the user document.
class SkillStat {
  final double avg;
  final int sessions;

  const SkillStat({required this.avg, required this.sessions});

  // Same rule as UserProfile: a stray value in one skill bucket must not
  // fail the profile it is nested inside.
  factory SkillStat.fromJson(Map<String, dynamic> json) => SkillStat(
        avg: json['avg'] is num ? (json['avg'] as num).toDouble() : 0.0,
        sessions: json['sessions'] is num ? (json['sessions'] as num).toInt() : 0,
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

  /// Learning module progress: list of completed scenarios with coins/scores.
  /// The raw `learningProgress` map from the user document: `coins`,
  /// `completedLevelIds`, `levels`, `attempts`, `levelCoins`, `responses`.
  ///
  /// Was typed as a list, which is not what the server stores — see
  /// learningController.js. Nothing read it, so the mismatch stayed hidden
  /// until a level was completed and the field appeared in the document;
  /// the cast then threw and failed the whole profile parse, which surfaces
  /// to the user as "Can't reach CommuniQ".
  final Map<String, dynamic> learningProgress;

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
    this.learningProgress = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final skillMap = _readMap(json['skillProgress']).map(
      (k, v) => MapEntry(k, SkillStat.fromJson(_readMap(v))),
    );

    return UserProfile(
      uid: _readString(json['uid']),
      email: _readString(json['email']),
      name: _readString(json['name']),
      photoURL: json['photoURL'] is String ? json['photoURL'] as String : null,
      xp: _readInt(json['xp']),
      level: _readInt(json['level'], fallback: 1),
      streak: _readInt(json['streak']),
      badges: _readStringList(json['badges']),
      isPremium: json['isPremium'] == true,
      skillProgress: skillMap,
      sessionsCompleted: _readInt(json['_sessionsCompleted']),
      learningProgress: _readLearningProgress(json),
    );
  }

  // ── Total readers ─────────────────────────────────────────────────────────
  //
  // A profile is the app's entry point: Home, session history and the
  // leaderboard all fail if it fails. A direct `as` cast on a field the server
  // renamed or retyped brings the whole screen down — which is exactly what
  // happened with `learningProgress` — so every field degrades to its default
  // instead of throwing.

  static String _readString(Object? v) => v is String ? v : '';

  static int _readInt(Object? v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _readMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<String> _readStringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : const <String>[];

  /// The server writes camelCase (learningController.js); `learning_progress`
  /// is kept as a fallback, and a list is tolerated because profiles cached
  /// under the old, wrong type are still on disk.
  static Map<String, dynamic> _readLearningProgress(Map<String, dynamic> json) =>
      _readMap(json['learningProgress'] ?? json['learning_progress']);

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
        'learningProgress': learningProgress,
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
        learningProgress: learningProgress,
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
