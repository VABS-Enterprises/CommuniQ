@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/theme/app_theme.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/models/communiq_level.dart';
import 'package:communiq/views/learning_view/screens/learning_session_screen.dart';

/// Renders the rebuilt learning screens to PNGs so the layout and contrast can
/// be reviewed by eye, not just asserted on.
///
/// Run with:
///   flutter test test/widget/learning_golden_test.dart \
///       --run-skipped --tags golden --update-goldens
///
/// These are review aids rather than pixel gates — the `golden` tag is skipped
/// by default (see dart_test.yaml) so a font or platform difference can never
/// fail CI.
Future<void> _loadFonts() async {
  final loader = FontLoader('Nunito');
  for (final path in ['assets/fonts/Nunito.ttf', 'assets/fonts/Nunito-Italic.ttf']) {
    loader.addFont(
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

CommuniqLevel _level() => CommuniqLevel.fromJson(const {
      'id': 6,
      'journey_id': 2,
      'journey_title': 'Speaking Up',
      'title': 'Saying No Without Guilt',
      'emoji': '🙅',
      'skill': 'Boundaries',
      'difficulty': 'beginner',
      'goal': 'Turn someone down clearly while keeping the relationship intact.',
      'scenario':
          'A friend texts at 9pm asking if you can help finish their assignment '
              'tonight. You are tired and have your own work, but you care about them.',
      'teaching': {
        'idea':
            'A good no has three parts: warmth, an unambiguous refusal, and a '
                'door left open.',
        'points': [
          'Warmth first, so the no does not read as rejection of them.',
          'Be unambiguous. "Maybe" creates a second conversation later.',
          'Offer a real alternative, or none at all — never a fake one.',
        ],
      },
      'mcqs': [
        {
          'step': 1,
          'question': 'Which response handles this best?',
          'options': [
            'I am a bit tied up tonight, maybe later.',
            'I would really like to help, but I have my own deadline tonight. '
                'Could we do it tomorrow morning instead?',
            'I do not think I will be able to help today.',
            'Sorry, I am busy.',
          ],
        },
        {
          'step': 2,
          'question': 'Why is "maybe later" worse than a straight no?',
          'options': [
            'It is less polite than a direct refusal.',
            'It makes you look indecisive to your friend.',
            'It leaves them waiting on you, so they cannot make other plans.',
            'It is too casual for a serious request.',
          ],
        },
      ],
      'response': {
        'prompt':
            'A colleague asks you to take on extra work this week when you are '
                'already at capacity. Write your reply.',
        'success_feedback': 'Warm, clear, and it does not leave them guessing.',
      },
    });

/// Advances past the staggered FadeInUp entrance without using
/// pumpAndSettle, which never returns here — the mascot animates forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _shoot(
  WidgetTester tester,
  String name, {
  int taps = 0,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2200)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: LearningSessionScreen(level: _level(), initialCoins: 240),
    ),
  );
  await _settle(tester);

  for (var i = 0; i < taps; i++) {
    final next = find.textContaining(RegExp(r"Let's go|Continue"));
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      await _settle(tester);
      await _settle(tester);
    }
  }

  await expectLater(
    find.byType(LearningSessionScreen),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);
  setUp(LearningProgressStore.instance.clear);

  testWidgets('lesson page', (t) => _shoot(t, 'session_1_lesson'));

  testWidgets('question page', (t) => _shoot(t, 'session_2_question', taps: 1));

  testWidgets('question page with a selection', (tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2200)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LearningSessionScreen(level: _level(), initialCoins: 240),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text("Let's go"));
    await _settle(tester);
    await _settle(tester);

    await tester.tap(find.textContaining('Could we do it tomorrow morning'));
    await _settle(tester);

    await expectLater(
      find.byType(LearningSessionScreen),
      matchesGoldenFile('goldens/session_3_selected.png'),
    );
  });
}
