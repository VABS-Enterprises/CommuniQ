import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens registered as go_router pages in app_router.dart.
///
/// Flutter refuses to let a page-based route be *completed* imperatively:
///
///   A page-based route cannot be completed using imperative api, provide a
///   new list without the corresponding Page to Navigator.pages instead.
///
/// This has broken the roleplay feature three separate times, and each time
/// the failure was invisible until runtime and looked like something else:
///
///   setup_scenario_page  Navigator.pushReplacement after POST /sessions/start
///                        had already created the session — every attempt to
///                        start a roleplay burned a session and went nowhere.
///
///   conversation screen  Navigator.pushReplacement after the AI evaluation
///                        had completed — the report was generated and stored,
///                        and the user never saw it. Reported as "evaluation
///                        is not working".
///
///   feedback screen      popUntil / pushReplacement on every button, so the
///                        results screen was a dead end.
///
/// Two things are deliberately NOT flagged:
///
///   `Navigator.push(...)`            pushing an imperative route on top of a
///                                    page is allowed; only *completing* the
///                                    page throws.
///   `Navigator.pop(dialogContext)`   a dialog or bottom sheet is its own
///                                    imperative route, so popping it with its
///                                    own context is correct. Only the
///                                    screen's own `context` is the problem.
const _pageBasedScreens = <String>[
  'lib/views/roleplay_view/screens/setup_scenario_page.dart',
  'lib/views/roleplay_view/screens/roleplay_conversation_screen.dart',
  'lib/views/roleplay_view/screens/roleplay_feedback_screen.dart',
  'lib/views/roleplay_view/screens/all_scenarios_page.dart',
  'lib/views/learning_view/screens/learning_view.dart',
];

/// Calls that complete the current route. Safe on an imperatively-pushed
/// route, fatal on a go_router page.
const _routeCompletingCalls = <String>[
  'Navigator.pop(context)',
  'Navigator.pop(context,',
  'Navigator.popUntil(context',
  'Navigator.pushReplacement(\n        context',
  'Navigator.pushReplacement(context',
  'Navigator.pushAndRemoveUntil(\n                context',
  'Navigator.pushAndRemoveUntil(context',
  'Navigator.of(context).pop(',
  'Navigator.of(context).popUntil(',
  'Navigator.of(context).pushReplacement(',
];

/// Strips comments so prose describing the bug isn't mistaken for the bug.
String _code(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('go_router page screens use router navigation', () {
    for (final path in _pageBasedScreens) {
      test('$path completes its route through go_router', () {
        final file = File(path);
        if (!file.existsSync()) {
          // A screen may legitimately be deleted; that is not a failure here.
          return;
        }
        final source = _code(file.readAsStringSync());

        final offenders = <String>[
          for (final call in _routeCompletingCalls)
            if (source.contains(call)) call,
        ];

        expect(
          offenders,
          isEmpty,
          reason:
              'This screen is a go_router page, so ${offenders.join(', ')} '
              'throws "A page-based route cannot be completed using '
              'imperative api" at runtime. Use context.pop() / '
              'context.pushReplacement() / context.go() instead.',
        );
      });
    }

    test('the guard actually detects the pattern it is guarding', () {
      // Without this, a typo in _routeCompletingCalls would make every test
      // above pass vacuously.
      const offending = 'void f() { Navigator.pop(context); }';
      expect(
        _routeCompletingCalls.any(_code(offending).contains),
        isTrue,
      );
      // ...and prose about the bug must not trip it.
      const prose = '// Navigator.pop(context) is what used to break here';
      expect(
        _routeCompletingCalls.any(_code(prose).contains),
        isFalse,
        reason: 'comments must be stripped before matching',
      );
    });
  });
}
