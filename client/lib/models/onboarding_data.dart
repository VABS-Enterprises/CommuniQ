import 'dart:convert';

/// Immutable snapshot of everything collected during the onboarding flow.
/// Built up incrementally as the user progresses through each screen.
/// Serialised to SharedPreferences so it survives app restarts between
/// onboarding completion and account creation.
class OnboardingData {
  final List<String> contexts;       // Screen 1 — where they want to improve
  final List<String> challenges;     // Screen 2 — what they struggle with
  final String? speakingStyle;       // Screen 3 — self-described speaking style
  final String? speakingNote;        // Screen 3 — optional free-text note
  final String? level;               // Screen 4 — Beginner / Intermediate / Advanced
  final String? primaryGoal;         // Screen 6 — the #1 thing to work on
  final int? commitmentDays;         // Commitment screen — 2, 3, or 5 days/week

  const OnboardingData({
    this.contexts = const [],
    this.challenges = const [],
    this.speakingStyle,
    this.speakingNote,
    this.level,
    this.primaryGoal,
    this.commitmentDays,
  });

  OnboardingData copyWith({
    List<String>? contexts,
    List<String>? challenges,
    String? speakingStyle,
    String? speakingNote,
    String? level,
    String? primaryGoal,
    int? commitmentDays,
  }) =>
      OnboardingData(
        contexts: contexts ?? this.contexts,
        challenges: challenges ?? this.challenges,
        speakingStyle: speakingStyle ?? this.speakingStyle,
        speakingNote: speakingNote ?? this.speakingNote,
        level: level ?? this.level,
        primaryGoal: primaryGoal ?? this.primaryGoal,
        commitmentDays: commitmentDays ?? this.commitmentDays,
      );

  Map<String, dynamic> toJson() => {
        'contexts': contexts,
        'challenges': challenges,
        if (speakingStyle != null) 'speakingStyle': speakingStyle,
        if (speakingNote != null && speakingNote!.isNotEmpty)
          'speakingNote': speakingNote,
        if (level != null) 'level': level,
        if (primaryGoal != null) 'primaryGoal': primaryGoal,
        if (commitmentDays != null) 'commitmentDays': commitmentDays,
      };

  factory OnboardingData.fromJson(Map<String, dynamic> json) => OnboardingData(
        contexts: List<String>.from(json['contexts'] as List? ?? []),
        challenges: List<String>.from(json['challenges'] as List? ?? []),
        speakingStyle: json['speakingStyle'] as String?,
        speakingNote: json['speakingNote'] as String?,
        level: json['level'] as String?,
        primaryGoal: json['primaryGoal'] as String?,
        commitmentDays: json['commitmentDays'] as int?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory OnboardingData.fromJsonString(String s) =>
      OnboardingData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
