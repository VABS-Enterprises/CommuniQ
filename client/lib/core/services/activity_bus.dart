import 'package:flutter/foundation.dart';

import 'package:communiq/core/services/session_service.dart';

/// What just changed on the server.
enum ActivityKind { roleplay, contest, learning, onboarding, profile }

/// App-wide signal that the user just earned XP or changed their profile.
///
/// The main tabs live in a `StatefulShellRoute.indexedStack`, so they keep
/// their state while other screens run on top of them — without this, Home,
/// Practise, Contest and Profile kept showing the XP, streak and history from
/// before a session until a pull-to-refresh or restart.
///
/// Call [ActivityBus.record] after any successful write; tabs listen and
/// reload what they show.
class ActivityBus extends ChangeNotifier {
  ActivityBus._();
  static final ActivityBus instance = ActivityBus._();

  ActivityKind? _last;
  ActivityKind? get last => _last;

  /// Refreshes the cached profile (which pushes [SessionService.profileUpdates])
  /// and notifies listeners. Never throws — a failed refresh must not turn a
  /// successful session into an error.
  Future<void> record(ActivityKind kind) async {
    _last = kind;
    notifyListeners();
    try {
      await SessionService.instance.refreshProfile();
    } catch (e) {
      debugPrint('[ActivityBus] profile refresh after $kind failed: $e');
    }
  }
}
