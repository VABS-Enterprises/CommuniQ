import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/services/leaderboard_service.dart';

void main() {
  group('LeaderboardService.parse', () {
    test('weekly rows carry this week\'s xp and all-time totalXp', () {
      final rows = LeaderboardService.parse(const {
        'leaderboard': [
          {
            'uid': 'u1',
            'name': 'Asha',
            'xp': 120,
            'totalXp': 4200,
            'level': 9,
            'badges': ['level_up'],
          },
        ],
      });
      expect(rows.single.xp, 120);
      expect(rows.single.totalXp, 4200);
      expect(rows.single.level, 9);
      expect(rows.single.badges, ['level_up']);
    });

    test('totalXp falls back to xp on the all-time board', () {
      final rows = LeaderboardService.parse(const {
        'leaderboard': [
          {'uid': 'u1', 'name': 'Asha', 'xp': 300, 'level': 2},
        ],
      });
      expect(rows.single.totalXp, 300);
    });

    test('tolerates missing and mistyped fields', () {
      final rows = LeaderboardService.parse(const {
        'leaderboard': [
          {'uid': 5, 'name': '', 'xp': '40', 'totalXp': null, 'badges': [1]},
          'not a row',
        ],
      });
      expect(rows, hasLength(1));
      expect(rows.single.uid, '');
      expect(rows.single.name, 'Anonymous');
      expect(rows.single.xp, 40);
      expect(rows.single.totalXp, 40);
      expect(rows.single.level, 1);
      expect(rows.single.badges, ['1']);
    });

    test('a malformed body is an empty board', () {
      expect(LeaderboardService.parse(const {'leaderboard': 'x'}), isEmpty);
      expect(LeaderboardService.parse(const {}), isEmpty);
    });
  });

  group('RequestSequencer', () {
    test('only the newest request may apply its result', () async {
      final sequencer = RequestSequencer();
      String? shown;

      Future<void> load(Future<String> request) async {
        final ticket = sequencer.next();
        final value = await request;
        if (sequencer.isCurrent(ticket)) shown = value;
      }

      // All-time requested, then the user flips to weekly before it returns.
      final allTime = Completer<String>();
      final weekly = Completer<String>();
      final first = load(allTime.future);
      final second = load(weekly.future);

      weekly.complete('weekly');
      await second;
      expect(shown, 'weekly');

      // The slow all-time response arrives last — and must be dropped.
      allTime.complete('all-time');
      await first;
      expect(shown, 'weekly');
    });

    test('a single request is current', () {
      final sequencer = RequestSequencer();
      final t = sequencer.next();
      expect(sequencer.isCurrent(t), isTrue);
      sequencer.next();
      expect(sequencer.isCurrent(t), isFalse);
    });
  });
}
