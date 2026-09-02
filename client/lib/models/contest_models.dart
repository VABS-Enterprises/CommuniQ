import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';

/// The contest formats the server's evaluator supports.
///
/// These four strings are validated server-side (`CONTEST_TYPES` in
/// contestController.js) — a value outside this set is rejected with a 400.
enum ContestType {
  debate('debate', 'Debate', 'Argue for or against a motion',
      Icons.gavel_rounded, AppColors.brand),
  gd('gd', 'Group Discussion', 'Make your point in a group',
      Icons.groups_rounded, AppColors.brand),
  extempore('extempore', 'Extempore', 'Speak on the spot',
      Icons.bolt_rounded, AppColors.brand),
  quiz('quiz', 'Quiz', 'Answer under pressure',
      Icons.quiz_rounded, AppColors.brand);

  const ContestType(this.id, this.label, this.blurb, this.icon, this.color);

  /// The wire value sent as `contestType`.
  final String id;

  final String label;
  final String blurb;
  final IconData icon;

  /// Always [AppColors.brand] — formats are told apart by icon and label, not
  /// by colour.
  final Color color;

  static ContestType fromId(String? id) => values.firstWhere(
        (t) => t.id == id,
        orElse: () => ContestType.debate,
      );
}

/// Per-dimension scores returned by the contest evaluator.
class ContestScores {
  const ContestScores({
    required this.argumentation,
    required this.evidence,
    required this.rebuttal,
    required this.delivery,
  });

  final double argumentation;
  final double evidence;
  final double rebuttal;
  final double delivery;

  factory ContestScores.fromJson(Map<String, dynamic> json) => ContestScores(
        argumentation: _num(json['argumentation']),
        evidence: _num(json['evidence']),
        rebuttal: _num(json['rebuttal']),
        delivery: _num(json['delivery']),
      );

  static double _num(dynamic v) => v is num ? v.toDouble() : 0;

  Map<String, double> get asMap => {
        'Argumentation': argumentation,
        'Evidence': evidence,
        'Rebuttal': rebuttal,
        'Delivery': delivery,
      };
}

/// The result of one graded submission (`POST /contest/submit`).
class ContestResult {
  const ContestResult({
    required this.attemptId,
    required this.scores,
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.feedback,
    required this.xpAwarded,
  });

  final String attemptId;
  final ContestScores scores;
  final double overallScore;
  final List<String> strengths;
  final List<String> improvements;
  final String feedback;
  final int xpAwarded;

  factory ContestResult.fromJson(Map<String, dynamic> json) => ContestResult(
        attemptId: json['attemptId'] as String? ?? '',
        scores: ContestScores.fromJson(
          (json['scores'] as Map<String, dynamic>?) ?? const {},
        ),
        overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
        strengths: _strings(json['strengths']),
        improvements: _strings(json['improvements']),
        feedback: json['feedback'] as String? ?? '',
        xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      );

  static List<String> _strings(dynamic v) =>
      v is List ? v.map((e) => '$e').toList() : const [];
}

/// One past submission (`GET /contest/history`).
class ContestAttempt {
  const ContestAttempt({
    required this.attemptId,
    required this.type,
    required this.overallScore,
    required this.xpAwarded,
    required this.motion,
    required this.submittedAt,
  });

  final String attemptId;
  final ContestType type;
  final double overallScore;
  final int xpAwarded;
  final String? motion;
  final DateTime? submittedAt;

  factory ContestAttempt.fromJson(Map<String, dynamic> json) => ContestAttempt(
        attemptId: json['attemptId'] as String? ?? '',
        type: ContestType.fromId(json['contestType'] as String?),
        overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
        xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
        motion: json['motion'] as String?,
        submittedAt: parseTimestamp(json['submittedAt']),
      );

  /// Firestore timestamps reach the client in several shapes depending on how
  /// the document was serialised — ISO string, epoch seconds/millis, or the
  /// admin SDK's `{_seconds, _nanoseconds}` object.
  static DateTime? parseTimestamp(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 100000000000 ? raw : raw * 1000,
      );
    }
    if (raw is Map) {
      final secs = raw['_seconds'] ?? raw['seconds'];
      if (secs is num) {
        return DateTime.fromMillisecondsSinceEpoch(secs.toInt() * 1000);
      }
    }
    return null;
  }
}

/// One row of the contest leaderboard (`GET /contest/leaderboard`).
class ContestRank {
  const ContestRank({
    required this.rank,
    required this.name,
    required this.score,
    required this.userId,
    required this.type,
  });

  final int rank;
  final String name;
  final double score;
  final String userId;
  final ContestType type;

  factory ContestRank.fromJson(Map<String, dynamic> json, int index) =>
      ContestRank(
        // The server returns rows already ordered; rank is the position unless
        // it supplies an explicit one.
        rank: (json['rank'] as num?)?.toInt() ?? index + 1,
        name: json['name'] as String? ?? 'User',
        score: (json['overallScore'] as num?)?.toDouble() ??
            (json['score'] as num?)?.toDouble() ??
            0,
        userId: json['userId'] as String? ?? '',
        type: ContestType.fromId(json['contestType'] as String?),
      );
}
