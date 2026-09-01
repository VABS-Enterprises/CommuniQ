// Component tests for the design system.
//
// These replace the previous `pumpWidget(const MyApp())` smoke test, which can
// no longer run: MyApp now builds the GoRouter, and the router's auth listener
// reaches FirebaseAuth at construction — which throws in a test binding with no
// initialised Firebase app. The components below are pure widgets with no
// platform dependencies, so they are both testable and the part of the app most
// worth protecting from regressions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/common_widgets/chunky_button.dart';
import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/chunky_progress_bar.dart';
import 'package:communiq/common_widgets/mascot/mascot.dart';
import 'package:communiq/common_widgets/option_card.dart';
import 'package:communiq/common_widgets/state_views.dart';
import 'package:communiq/core/theme/app_theme.dart';

/// Wraps a widget in the real app theme so tests exercise the same text styles
/// and colours the app ships.
///
/// Note: anything containing a [Mascot] must be driven with `pump()` rather
/// than `pumpAndSettle()` — the mascot's idle animation repeats indefinitely,
/// so the tree never reaches a settled state.
Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ChunkyButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(ChunkyButton(label: 'Go', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('does not fire when onPressed is null', (tester) async {
      await tester.pumpWidget(
        host(const ChunkyButton(label: 'Go', onPressed: null)),
      );

      await tester.tap(find.text('Go'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Nothing to assert beyond "no exception" — a disabled button must not
      // throw when tapped.
      expect(tester.takeException(), isNull);
    });

    testWidgets('swaps the label for a spinner while loading', (tester) async {
      await tester.pumpWidget(
        host(ChunkyButton(label: 'Saving', loading: true, onPressed: () {})),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving'), findsNothing);
    });

    testWidgets('a loading button ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(ChunkyButton(
          label: 'Saving',
          loading: true,
          onPressed: () => taps++,
        )),
      );

      await tester.tap(find.byType(ChunkyButton), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('ChunkyProgressBar', () {
    testWidgets('clamps out-of-range values without throwing', (tester) async {
      for (final v in [-1.0, 0.0, 0.5, 1.0, 4.2, double.nan]) {
        await tester.pumpWidget(host(ChunkyProgressBar(value: v)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'value=$v');
      }
    });

    testWidgets('renders a percentage label when asked', (tester) async {
      await tester.pumpWidget(
        host(const SizedBox(
          width: 200,
          child: ChunkyProgressBar(value: 0.42, showLabel: true),
        )),
      );

      expect(find.text('42%'), findsOneWidget);
    });
  });

  group('ChunkyCard', () {
    testWidgets('is tappable only when given onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(ChunkyCard(
          onTap: () => taps++,
          child: const Text('body'),
        )),
      );

      await tester.tap(find.text('body'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('OptionCard', () {
    testWidgets('reports selection', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        host(OptionCard(
          title: 'Public speaking',
          selected: false,
          onTap: () => selected = 1,
        )),
      );

      await tester.tap(find.text('Public speaking'));
      await tester.pumpAndSettle();

      expect(selected, 1);
    });

    testWidgets('a disabled card does not report selection', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(OptionCard(
          title: 'Locked',
          selected: false,
          enabled: false,
          onTap: () => taps++,
        )),
      );

      await tester.tap(find.text('Locked'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(taps, 0);
    });
  });

  group('State views', () {
    testWidgets('EmptyState shows its action and fires it', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(EmptyState(
          title: 'Nothing here',
          message: 'Try a session first.',
          actionLabel: 'Start',
          onAction: () => tapped = true,
        )),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('ErrorStateView always offers a retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        host(ErrorStateView(
          message: 'Offline',
          onRetry: () => retried = true,
        )),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('states survive a short viewport without overflowing',
        (tester) async {
      // Regression: both states were fixed-height columns and overflowed in a
      // constrained slot. They must scroll instead.
      await tester.pumpWidget(
        host(const SizedBox(
          height: 160,
          width: 300,
          child: EmptyState(title: 'Nothing here', message: 'A message.'),
        )),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Mascot', () {
    testWidgets('renders every mood without throwing', (tester) async {
      for (final mood in MascotMood.values) {
        await tester.pumpWidget(host(Mascot(mood: mood, animate: false)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: mood.name);
      }
    });

    testWidgets('animates and disposes cleanly', (tester) async {
      await tester.pumpWidget(host(const Mascot(mood: MascotMood.idle)));
      await tester.pump(const Duration(milliseconds: 600));

      // Replacing the mascot must tear its controllers down without error.
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('morphs between moods', (tester) async {
      await tester.pumpWidget(host(const Mascot(mood: MascotMood.idle)));
      await tester.pump();

      await tester.pumpWidget(host(const Mascot(mood: MascotMood.celebrating)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });
}
