import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/learning_service.dart';
import 'package:communiq/models/communiq_level.dart';

/// One level exactly as `GET /levels` serves it — answer key stripped,
/// options pre-shuffled by the server.
Map<String, dynamic> _levelJson() => {
      'id': 6,
      'journey_id': 2,
      'journey_title': 'Speaking Up',
      'title': 'Saying No Without Guilt',
      'emoji': '🙅',
      'skill': 'Boundaries',
      'difficulty': 'beginner',
      'goal': 'Turn someone down clearly.',
      'scenario': 'A friend texts at 9pm asking for help.',
      'teaching': {
        'idea': 'A good no has three parts.',
        'points': ['Warmth first.', 'Be unambiguous.'],
      },
      'mcq_count': 2,
      'mcqs': [
        {
          'step': 1,
          'question': 'Which response handles this best?',
          'options': ['A', 'B', 'C', 'D'],
        },
        {
          'step': 2,
          'question': 'Why is "maybe later" worse?',
          'options': ['E', 'F', 'G', 'H'],
        },
      ],
      'response': {'prompt': 'Write your reply.', 'success_feedback': 'Nice.'},
    };

void main() {
  group('CommuniqLevel', () {
    test('parses the full content payload', () {
      final level = CommuniqLevel.fromJson(_levelJson());

      expect(level.id, 6);
      expect(level.title, 'Saying No Without Guilt');
      expect(level.emoji, '🙅');
      expect(level.skill, 'Boundaries');
      expect(level.difficulty, 'beginner');
      expect(level.goal, isNotEmpty);
      expect(level.teaching.idea, 'A good no has three parts.');
      expect(level.teaching.points, hasLength(2));
      expect(level.mcqs, hasLength(2));
      expect(level.responsePrompt, 'Write your reply.');
    });

    test('totalSteps counts the written response as a step', () {
      expect(CommuniqLevel.fromJson(_levelJson()).totalSteps, 3);
    });

    test('carries no answer key — the server never sends one', () {
      final level = CommuniqLevel.fromJson(_levelJson());
      // Every option must survive; none of them may be flagged as correct.
      expect(level.mcqs.first.options, ['A', 'B', 'C', 'D']);
      expect(
        CommuniqMCQ.fromJson(const {'step': 1, 'question': 'q'}).options,
        isEmpty,
        reason: 'a malformed step must not crash the parser',
      );
    });

    test('survives missing optional content without throwing', () {
      final level = CommuniqLevel.fromJson({'id': 1});
      expect(level.emoji, isNotEmpty);
      expect(level.teaching.isEmpty, isTrue);
      expect(level.mcqs, isEmpty);
      expect(level.totalSteps, 1);
    });
  });

  group('CommuniqJourney', () {
    test('matches levels by declared range', () {
      final journey = CommuniqJourney.fromJson(const {
        'id': 2,
        'title': 'Speaking Up',
        'subtitle': 'Say the thing you mean to say',
        'emoji': '📣',
        'start_level': 6,
        'end_level': 10,
      });

      expect(journey.contains(6), isTrue);
      expect(journey.contains(10), isTrue);
      expect(journey.contains(5), isFalse);
      expect(journey.contains(11), isFalse);
    });
  });

  group('LearningProgress', () {
    test('parses the server snapshot', () {
      final progress = LearningProgress.fromJson(const {
        'coins': 120,
        'completedLevelIds': [1, 2],
        'levelProgress': {
          '3': {'1': true, '2': false},
        },
        'levelCoins': {'1': 60, '3': 10},
        'responses': {
          '1': {'score': 82, 'coins': 15},
        },
        'stepTotals': {'3': 4},
      });

      expect(progress.coins, 120);
      expect(progress.completedLevelIds, {1, 2});
      expect(progress.stepsSolved(3), 1);
      expect(progress.levelCoins[1], 60);
      expect(progress.responseScores[1], 82);
      expect(progress.stepTotals[3], 4);
    });

    test('defaults cleanly when the server omits the new fields', () {
      final progress = LearningProgress.fromJson(const {'coins': 5});
      expect(progress.completedLevelIds, isEmpty);
      expect(progress.levelCoins, isEmpty);
      expect(progress.stepsSolved(1), 0);
    });
  });

  group('LearningAnswerResult', () {
    test('reads a correct answer', () {
      final r = LearningAnswerResult.fromJson(const {
        'correct': true,
        'coinsAwarded': 10,
        'totalCoins': 110,
        'attemptNumber': 1,
        'feedback': 'Exactly.',
        'correctOption': 'A',
        'stepsSolved': 2,
        'totalSteps': 4,
      });

      expect(r.correct, isTrue);
      expect(r.coinsAwarded, 10);
      expect(r.correctOption, 'A');
      expect(r.revealed, isFalse);
      expect(r.stepsSolved, 2);
    });

    test('a first miss withholds the answer; a second miss reveals it', () {
      final firstMiss = LearningAnswerResult.fromJson(const {
        'correct': false,
        'attemptNumber': 1,
        'feedback': 'Not quite.',
      });
      expect(firstMiss.correctOption, isNull);
      expect(firstMiss.revealed, isFalse);

      final secondMiss = LearningAnswerResult.fromJson(const {
        'correct': false,
        'attemptNumber': 2,
        'feedback': 'Not quite.',
        'correctOption': 'B',
        'revealed': true,
      });
      expect(secondMiss.correctOption, 'B');
      expect(secondMiss.revealed, isTrue);
    });
  });

  group('LearningProgressStore', () {
    setUp(LearningProgressStore.instance.clear);

    test('a graded answer updates coins and step progress immediately', () {
      final store = LearningProgressStore.instance;
      var notifications = 0;
      void listener() => notifications++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      expect(store.stepsSolved(6), 0);

      store.applyAnswer(
        levelId: 6,
        step: 1,
        result: const LearningAnswerResult(
          correct: true,
          coinsAwarded: 10,
          totalCoins: 110,
          attemptNumber: 1,
          feedback: 'Exactly.',
          totalSteps: 4,
        ),
      );

      expect(store.coins, 110);
      expect(store.stepsSolved(6), 1);
      expect(store.coinsFor(6), 10);
      expect(store.isStepSolved(6, 1), isTrue);
      expect(store.isStepSolved(6, 2), isFalse);
      expect(notifications, 1, reason: 'listeners must fire for a live update');
    });

    test('a wrong answer changes nothing', () {
      final store = LearningProgressStore.instance;
      store.applyAnswer(
        levelId: 6,
        step: 1,
        result: const LearningAnswerResult(
          correct: false,
          coinsAwarded: 0,
          totalCoins: 100,
          attemptNumber: 1,
          feedback: 'Not quite.',
        ),
      );
      expect(store.coins, 0);
      expect(store.stepsSolved(6), 0);
    });

    test('answering two steps does not clobber the first', () {
      final store = LearningProgressStore.instance;
      for (final step in [1, 2]) {
        store.applyAnswer(
          levelId: 6,
          step: step,
          result: LearningAnswerResult(
            correct: true,
            coinsAwarded: 10,
            totalCoins: 100 + step * 10,
            attemptNumber: 1,
            feedback: 'Exactly.',
            totalSteps: 4,
          ),
        );
      }
      expect(store.stepsSolved(6), 2);
      expect(store.coinsFor(6), 20);
    });

    test('completion marks the level done and banks the bonus', () {
      final store = LearningProgressStore.instance;
      store.applyCompletion(
        levelId: 6,
        responseScore: 82,
        result: const LevelCompletionResult(
          completedLevelIds: [6],
          coinsAwarded: 35,
          totalCoins: 175,
          levelCoins: 75,
          alreadyComplete: false,
        ),
      );

      expect(store.isComplete(6), isTrue);
      expect(store.coins, 175);
      expect(store.coinsFor(6), 75);
      expect(store.progress.responseScores[6], 82);
    });

    test('fractionFor tracks partial progress and completion', () {
      final store = LearningProgressStore.instance;
      expect(store.fractionFor(6, 4), 0.0);

      store.applyAnswer(
        levelId: 6,
        step: 1,
        result: const LearningAnswerResult(
          correct: true,
          coinsAwarded: 10,
          totalCoins: 10,
          attemptNumber: 1,
          feedback: '',
          totalSteps: 4,
        ),
      );
      // 1 of 5 steps (4 questions + the written response).
      expect(store.fractionFor(6, 4), closeTo(0.2, 0.001));

      store.applyCompletion(
        levelId: 6,
        result: const LevelCompletionResult(
          completedLevelIds: [6],
          coinsAwarded: 20,
          totalCoins: 30,
          levelCoins: 30,
          alreadyComplete: false,
        ),
      );
      expect(store.fractionFor(6, 4), 1.0);
    });

    test('clear wipes the previous user', () {
      final store = LearningProgressStore.instance;
      store.applyCompletion(
        levelId: 6,
        result: const LevelCompletionResult(
          completedLevelIds: [6],
          coinsAwarded: 20,
          totalCoins: 200,
          levelCoins: 20,
          alreadyComplete: false,
        ),
      );
      expect(store.coins, 200);

      store.clear();
      expect(store.coins, 0);
      expect(store.completedLevelIds, isEmpty);
      expect(store.isLoaded, isFalse);
    });
  });

  group('Light-theme migration', () {
    // The learning session screen shipped written for the old dark theme: it
    // drew option text in `Colors.white` on `AppColors.surface`, which the
    // light palette redefined to pure white. The answers were invisible — the
    // whole reason this screen was rebuilt. Guard the class of bug, not just
    // the instance, since a copy-paste from another dark-era screen would
    // reintroduce it silently.
    const files = [
      'lib/views/learning_view/screens/learning_session_screen.dart',
      'lib/views/learning_view/screens/learning_view.dart',
    ];

    for (final path in files) {
      test('$path hardcodes no white/black text colours', () {
        // Comments are stripped first: these files document the original bug
        // by name, and prose about `Colors.white` is not a use of it.
        final source = File(path)
            .readAsStringSync()
            .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        final offenders = <String>[];

        for (final pattern in const [
          'Colors.white',
          'Colors.black',
          'Color(0xFFFFFFFF)',
        ]) {
          if (source.contains(pattern)) offenders.add(pattern);
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Use AppColors (ink / inkOnDark / surface) so the screen '
              'follows the palette. Found: ${offenders.join(', ')}',
        );
      });
    }
  });
}
