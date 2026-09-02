import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/learning_service.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/learning_view/screens/learning_session_screen.dart';

const _optionA = 'I would really like to help, but I have my own deadline.';
const _optionB = 'I am a bit tied up tonight, maybe later.';
const _optionC = 'I do not think I will be able to help today.';
const _optionD = 'Sorry, I am busy.';

CommuniqLevel _level() => CommuniqLevel.fromJson(const {
      'id': 6,
      'journey_id': 2,
      'journey_title': 'Speaking Up',
      'title': 'Saying No Without Guilt',
      'emoji': '🙅',
      'skill': 'Boundaries',
      'difficulty': 'beginner',
      'goal': 'Turn someone down clearly while keeping the relationship.',
      'scenario': 'A friend texts at 9pm asking if you can help tonight.',
      'teaching': {
        'idea': 'A good no has three parts: warmth, a clear refusal, an open door.',
        'points': ['Warmth first.', 'Be unambiguous.', 'Offer a real alternative.'],
      },
      'mcqs': [
        {
          'step': 1,
          'question': 'Which response handles this best?',
          'options': [_optionA, _optionB, _optionC, _optionD],
        },
      ],
      'response': {
        'prompt': 'Write your reply.',
        'success_feedback': 'Warm, clear and unambiguous.',
      },
    });

Future<void> _pumpSession(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LearningSessionScreen(level: _level(), initialCoins: 40),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

/// Every ancestor colour that could be painting behind [finder].
Set<Color> _backgroundsBehind(WidgetTester tester, Finder finder) {
  final colors = <Color>{};
  for (final container in tester.widgetList<Container>(
    find.ancestor(of: finder, matching: find.byType(Container)),
  )) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      colors.add(decoration.color!);
    }
    if (container.color != null) colors.add(container.color!);
  }
  for (final material in tester.widgetList<Material>(
    find.ancestor(of: finder, matching: find.byType(Material)),
  )) {
    if (material.color != null) colors.add(material.color!);
  }
  return colors;
}

void main() {
  setUp(LearningProgressStore.instance.clear);

  group('Learning session — lesson page', () {
    testWidgets('teaches the idea before asking anything', (tester) async {
      await _pumpSession(tester);

      expect(find.text('Saying No Without Guilt'), findsOneWidget);
      expect(
        find.text(
          'A good no has three parts: warmth, a clear refusal, an open door.',
        ),
        findsOneWidget,
      );
      expect(find.text('Warmth first.'), findsOneWidget);
      expect(find.text('Offer a real alternative.'), findsOneWidget);
      expect(
        find.text('A friend texts at 9pm asking if you can help tonight.'),
        findsOneWidget,
      );

      // The questions come after the lesson, not before it.
      expect(find.text('Which response handles this best?'), findsNothing);
    });

    testWidgets('shows the running coin total from the server', (tester) async {
      await _pumpSession(tester);
      expect(find.text('40'), findsOneWidget);
    });
  });

  group('Learning session — question page', () {
    testWidgets('renders the question and every option', (tester) async {
      await _pumpSession(tester);

      await tester.tap(find.text("Let's go"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Which response handles this best?'), findsOneWidget);
      for (final option in [_optionA, _optionB, _optionC, _optionD]) {
        expect(find.text(option), findsOneWidget, reason: 'missing: $option');
      }
      expect(find.text('Question 1 of 1'), findsOneWidget);
    });

    testWidgets('option text is never the same colour as its background',
        (tester) async {
      // The regression this screen was rebuilt for: option text was drawn in
      // Colors.white on AppColors.surface, which the light palette redefined
      // to pure white. The answers rendered, but were invisible.
      await _pumpSession(tester);
      await tester.tap(find.text("Let's go"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      for (final option in [_optionA, _optionB, _optionC, _optionD]) {
        final finder = find.text(option);
        final color = tester.widget<Text>(finder).style?.color;

        expect(color, isNotNull, reason: '$option has no explicit colour');
        expect(
          color,
          isNot(AppColors.surface),
          reason: 'option text matches the card fill — invisible',
        );
        expect(
          _backgroundsBehind(tester, finder),
          isNot(contains(color)),
          reason: 'option text matches a background painted behind it',
        );
      }
    });

    testWidgets('selecting an option enables Check', (tester) async {
      await _pumpSession(tester);
      await tester.tap(find.text("Let's go"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Nothing selected yet, so the primary action is inert.
      expect(find.text('Check'), findsOneWidget);

      await tester.tap(find.text(_optionA));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Still on the question — selection alone must not grade or advance.
      expect(find.text(_optionA), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
    });

    testWidgets('can go back to the lesson from a question', (tester) async {
      await _pumpSession(tester);
      await tester.tap(find.text("Let's go"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Which response handles this best?'), findsOneWidget);
    });
  });

  group('Learning session — resume', () {
    testWidgets('a step already solved on the server is not asked again',
        (tester) async {
      // Server says step 1 of level 6 is done.
      LearningProgressStore.instance.applyAnswer(
        levelId: 6,
        step: 1,
        result: const LearningAnswerResult(
          correct: true,
          coinsAwarded: 10,
          totalCoins: 50,
          attemptNumber: 1,
          feedback: 'Correct!',
          totalSteps: 1,
        ),
      );

      await _pumpSession(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Skips the solved question and lands on the written response.
      expect(find.text('Your turn'), findsOneWidget);
      expect(find.text('Write your reply.'), findsOneWidget);
    });
  });
}
