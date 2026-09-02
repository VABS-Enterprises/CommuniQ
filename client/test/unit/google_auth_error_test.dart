import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/services/auth_service.dart';

/// The exception Google Play Services actually produced on a device with no
/// working DNS. The status code is buried in the message, not the code — the
/// only thing separating "you're offline" from "this build isn't registered".
PlatformException _gms(String code, int status) => PlatformException(
      code: code,
      message: 'com.google.android.gms.common.api.ApiException: $status: ',
    );

String _messageOf(Exception e) => e.toString().replaceFirst('Exception: ', '');

void main() {
  group('Google Sign-In error mapping', () {
    test('a network failure says so instead of "try again"', () {
      // Verbatim from the emulator: PlatformException(network_error,
      // com.google.android.gms.common.api.ApiException: 7: , null, null)
      final result = AuthService.googleSignInErrorFor(_gms('network_error', 7));
      expect(_messageOf(result), contains('connection'));
      expect(
        _messageOf(result),
        isNot(contains('Google Sign-In failed')),
        reason: 'the generic fallback hides the cause the user must fix',
      );
    });

    test('a developer error names the actual fix', () {
      final result = AuthService.googleSignInErrorFor(_gms('sign_in_failed', 10));
      expect(_messageOf(result), contains('signingReport'));
    });

    test('a dismissed picker is a cancellation, not a failure', () {
      expect(
        AuthService.googleSignInErrorFor(_gms('sign_in_canceled', 12501)),
        isA<CancelledException>(),
      );
    });

    test('a sign-in already running is reported distinctly', () {
      expect(
        _messageOf(AuthService.googleSignInErrorFor(_gms('sign_in_failed', 12502))),
        contains('already in progress'),
      );
    });

    test('play services trouble is distinguished from a network failure', () {
      final result = AuthService.googleSignInErrorFor(_gms('sign_in_failed', 12500));
      expect(_messageOf(result), contains('Play'));
      expect(_messageOf(result), isNot(contains('connection')));
    });

    test('a bare network_error with no status code still maps correctly', () {
      final result = AuthService.googleSignInErrorFor(
        PlatformException(code: 'network_error', message: null),
      );
      expect(_messageOf(result), contains('connection'));
    });

    test('an unrecognised failure falls back without crashing', () {
      final result = AuthService.googleSignInErrorFor(
        PlatformException(code: 'something_new', message: 'unmapped'),
      );
      expect(_messageOf(result), contains('Google Sign-In failed'));
    });
  });
}
