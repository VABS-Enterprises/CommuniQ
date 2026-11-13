import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/core/services/contest_service.dart';
import 'package:communiq/core/services/leaderboard_service.dart';
import 'package:communiq/core/services/learning_progress_store.dart';
import 'package:communiq/core/services/level_service.dart';
import 'package:communiq/core/services/profile_cache_service.dart';
import 'package:communiq/core/services/session_service.dart';

/// Loads what the main tabs need while the splash screen is showing, so the
/// app opens on real data instead of a row of spinners.
///
/// Every request goes through [ApiService]'s cache interceptor, which means
/// each one either brings back fresh data from the server (Firestore, via the
/// Node backend) and saves it, or — on a weak or missing connection — falls
/// back to the copy saved last time. The screens that open next then read the
/// just-fetched responses from memory instead of asking again.
///
/// Nothing here can fail the launch: each task swallows its own error, and
/// the whole warm-up is capped at [budget]. A slow network costs the user at
/// most that long on the splash; the screens finish anything left over.
class AppBootstrap {
  AppBootstrap._();

  /// Longest the splash will wait for data before opening the app anyway.
  static const budget = Duration(seconds: 8);

  /// Fetches the signed-in user's data for the main tabs, in parallel.
  static Future<void> warmUp() async {
    final sw = Stopwatch()..start();
    final tasks = <String, Future<Object?> Function()>{
      // Network first (refreshProfile), so the home header shows today's
      // numbers rather than the last session's; it saves to the profile
      // cache, and a connection failure falls back to the saved copy.
      'profile': () async {
        try {
          return await SessionService.instance.refreshProfile();
        } catch (_) {
          // Nothing reachable and nothing saved by the interceptor — the
          // secure profile cache may still have a copy for the home screen.
          return ProfileCacheService.load();
        }
      },
      'curriculum': LevelService.instance.fetchCurriculum,
      'progress': LearningProgressStore.instance.refresh,
      'sessions': SessionService.instance.fetchSessionHistory,
      'leaderboard': LeaderboardService.fetchAllTime,
      'contests': () => ContestService.instance.history(limit: 5),
    };

    await Future.wait(
      tasks.entries.map((t) => t.value().then<void>((_) {
            debugPrint('[Bootstrap] ${t.key} ✓');
          }).catchError((Object e) {
            debugPrint('[Bootstrap] ${t.key} ✗ $e');
          })),
    ).timeout(budget, onTimeout: () {
      debugPrint('[Bootstrap] budget reached — opening with what is ready');
      return const [];
    });
    debugPrint('[Bootstrap] warm-up done in ${sw.elapsedMilliseconds} ms');
  }

  /// Decodes the scenario artwork into Flutter's image cache so the roleplay
  /// tab and the home carousel don't pop images in one by one.
  static Future<void> precacheImages(BuildContext context) async {
    final paths = kScenarioPresets.map((p) => p.image).toSet();
    await Future.wait(paths.map((path) => precacheImage(
          AssetImage(path),
          context,
          onError: (e, _) => debugPrint('[Bootstrap] image $path ✗ $e'),
        )));
  }
}
