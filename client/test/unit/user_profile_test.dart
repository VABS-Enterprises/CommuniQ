import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/models/user_profile.dart';

void main() {
  group('UserProfile.fromJson learningProgress', () {
    // The server stores an object, not a list (learningController.js:
    // coins / completedLevelIds / levels / attempts / levelCoins / responses).
    test('reads the object shape the server actually sends', () {
      final profile = UserProfile.fromJson({
        'uid': 'u1',
        'learningProgress': {
          'coins': 40,
          'completedLevelIds': ['level_1'],
          'levels': {'level_1': {'1': true}},
        },
      });

      expect(profile.learningProgress['coins'], 40);
      expect(profile.learningProgress['completedLevelIds'], ['level_1']);
    });

    test('falls back to the snake_case key', () {
      final profile = UserProfile.fromJson({
        'uid': 'u1',
        'learning_progress': {'coins': 7},
      });
      expect(profile.learningProgress['coins'], 7);
    });

    test('tolerates a list left over in an old cache', () {
      // This field used to be typed as a list, so profiles cached under the
      // wrong shape are still on disk. Reading one must not throw.
      final profile = UserProfile.fromJson({
        'uid': 'u1',
        'learningProgress': <dynamic>[],
      });
      expect(profile.learningProgress, isEmpty);
    });

    test('missing key yields empty, not an error', () {
      expect(UserProfile.fromJson({'uid': 'u1'}).learningProgress, isEmpty);
    });
  });

  group('UserProfile.fromJson robustness', () {
    // A profile that fails to parse takes Home, sessions and the leaderboard
    // down with it, so no single malformed field may throw.
    test('survives every field arriving as the wrong type', () {
      late UserProfile profile;

      expect(
        () => profile = UserProfile.fromJson({
          'uid': 42,
          'email': <String>[],
          'name': {'nope': true},
          'xp': 'lots',
          'level': null,
          'badges': {'not': 'a list'},
          'isPremium': 'yes',
          'skillProgress': <dynamic>[],
          'learningProgress': 'nonsense',
        }),
        returnsNormally,
      );

      // And degrades to the documented defaults rather than half-filled junk.
      expect(profile.uid, '');
      expect(profile.xp, 0);
      expect(profile.level, 1);
      expect(profile.badges, isEmpty);
      expect(profile.isPremium, isFalse);
      expect(profile.learningProgress, isEmpty);
    });

    test('a well-formed profile still parses', () {
      final profile = UserProfile.fromJson({
        'uid': 'abc',
        'email': 'a@b.c',
        'name': 'Molly',
        'xp': 120,
        'level': 3,
        'streak': 5,
        'badges': ['first_session'],
        'isPremium': true,
      });

      expect(profile.uid, 'abc');
      expect(profile.name, 'Molly');
      expect(profile.xp, 120);
      expect(profile.level, 3);
      expect(profile.streak, 5);
      expect(profile.badges, ['first_session']);
      expect(profile.isPremium, isTrue);
    });
  });
}
