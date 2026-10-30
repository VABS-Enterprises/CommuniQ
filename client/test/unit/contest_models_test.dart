import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/models/contest_models.dart';

void main() {
  group('ContestResult.fromJson', () {
    test('parses the XP, level, streak and badges from submit', () {
      final r = ContestResult.fromJson(const {
        'attemptId': 'a1',
        'scores': {
          'argumentation': 80,
          'evidence': 70,
          'rebuttal': 60,
          'delivery': 90,
        },
        'overallScore': 75,
        'strengths': ['Clear'],
        'improvements': ['More data'],
        'feedback': 'Solid.',
        'xpAwarded': 30,
        'newLevel': 4,
        'leveledUp': true,
        'newStreak': 3,
        'newBadges': ['level_up'],
      });
      expect(r.overallScore, 75);
      expect(r.scores.delivery, 90);
      expect(r.xpAwarded, 30);
      expect(r.newLevel, 4);
      expect(r.leveledUp, isTrue);
      expect(r.newStreak, 3);
      expect(r.newBadges, ['level_up']);
    });

    test('tolerates an older response without the progress fields', () {
      final r = ContestResult.fromJson(const {
        'attemptId': 'a1',
        'overallScore': 62.5,
        'xpAwarded': 10,
      });
      expect(r.overallScore, 62.5);
      expect(r.newLevel, isNull);
      expect(r.leveledUp, isFalse);
      expect(r.newStreak, isNull);
      expect(r.newBadges, isEmpty);
      expect(r.strengths, isEmpty);
    });

    test('tolerates wrong types instead of throwing', () {
      final r = ContestResult.fromJson(const {
        'scores': 'oops',
        'overallScore': '70',
        'xpAwarded': null,
        'newLevel': '5',
        'leveledUp': 'yes',
        'newBadges': null,
        'feedback': 3,
      });
      expect(r.overallScore, 70);
      expect(r.xpAwarded, 0);
      expect(r.newLevel, 5);
      expect(r.leveledUp, isFalse);
      expect(r.feedback, '');
    });
  });

  group('ContestHistory.fromJson', () {
    test('uses the server stats over every attempt, not the page', () {
      final h = ContestHistory.fromJson(const {
        'attempts': [
          {'attemptId': 'x', 'contestType': 'debate', 'overallScore': 50},
        ],
        'stats': {
          'attempts': 12,
          'bestScore': 91,
          'bestByType': {'debate': 91, 'quiz': 64, 'unknown': 10},
        },
      });
      expect(h.attempts, hasLength(1));
      expect(h.stats!.attempts, 12);
      expect(h.stats!.bestScore, 91);
      expect(h.stats!.bestByType, {
        ContestType.debate: 91.0,
        ContestType.quiz: 64.0,
      });
    });

    test('stats are null when an older server omits them', () {
      final h = ContestHistory.fromJson(const {'attempts': []});
      expect(h.attempts, isEmpty);
      expect(h.stats, isNull);
    });
  });

  group('ContestRank.fromJson', () {
    test('falls back to position and a placeholder name', () {
      final r = ContestRank.fromJson(const {'name': '  ', 'score': 40}, 2);
      expect(r.rank, 3);
      expect(r.name, 'User');
      expect(r.score, 40);
    });
  });
}
