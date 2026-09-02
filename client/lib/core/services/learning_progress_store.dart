import 'package:flutter/foundation.dart';

import 'package:communiq/core/services/learning_service.dart';

/// Live learning progress, shared by every screen that shows it.
///
/// The journey map used to read progress once in `initState` and only find
/// out about an answer after the session screen popped and handed back a
/// result map. Anything else showing progress (the home tab's continue card,
/// the coin total in a header) stayed stale until its own next fetch.
///
/// Now there is one snapshot. The session screen folds each graded answer
/// into it as the server confirms it, and every listener repaints in the same
/// frame — so a level's ring fills while the user is still inside it.
///
/// The server remains authoritative: [applyAnswer] and [applyCompletion] only
/// ever write values the server just returned, and [refresh] reconciles the
/// whole snapshot against `GET /learning/progress`.
class LearningProgressStore extends ChangeNotifier {
  LearningProgressStore._();
  static final LearningProgressStore instance = LearningProgressStore._();

  LearningProgress _progress = const LearningProgress.empty();
  LearningProgress get progress => _progress;

  bool _loaded = false;

  /// True once a server snapshot has been folded in — until then the values
  /// are defaults, not facts, and callers should show a loading state.
  bool get isLoaded => _loaded;

  /// True when the last [refresh] failed and the values shown are stale.
  bool _stale = false;
  bool get isStale => _stale;

  int get coins => _progress.coins;
  Set<int> get completedLevelIds => _progress.completedLevelIds;

  bool isComplete(int levelId) => _progress.completedLevelIds.contains(levelId);

  /// MCQ steps answered correctly in [levelId].
  int stepsSolved(int levelId) => _progress.stepsSolved(levelId);

  /// Coins banked in [levelId].
  int coinsFor(int levelId) => _progress.levelCoins[levelId] ?? 0;

  /// Whether a specific MCQ step is already solved — used to resume a level
  /// part-way through instead of restarting it.
  bool isStepSolved(int levelId, int step) =>
      (_progress.levelProgress[levelId] ?? const {})[step] == true;

  /// Fraction of [levelId] finished, counting the written response as the
  /// final step. Returns 1.0 for a completed level.
  double fractionFor(int levelId, int mcqCount) {
    if (isComplete(levelId)) return 1.0;
    final total = mcqCount + 1;
    if (total <= 0) return 0;
    return (stepsSolved(levelId) / total).clamp(0.0, 1.0);
  }

  /// Pulls the authoritative snapshot. Never throws — a failure leaves the
  /// previous values in place and flips [isStale], so the UI can show cached
  /// progress behind a banner rather than an error page.
  Future<bool> refresh() async {
    try {
      final next = await LearningService.getProgress();
      _progress = next;
      _loaded = true;
      _stale = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[LearningProgressStore] refresh failed: $e');
      _stale = true;
      notifyListeners();
      return false;
    }
  }

  /// Folds a graded MCQ answer into the snapshot immediately.
  ///
  /// Only called with a [LearningAnswerResult] the server just returned, so
  /// this stays consistent with the server without waiting for a round trip.
  void applyAnswer({
    required int levelId,
    required int step,
    required LearningAnswerResult result,
  }) {
    if (!result.correct) return;

    final levelProgress = {
      for (final e in _progress.levelProgress.entries) e.key: {...e.value},
    };
    (levelProgress[levelId] ??= {})[step] = true;

    _progress = LearningProgress(
      coins: result.totalCoins,
      completedLevelIds: _progress.completedLevelIds,
      levelProgress: levelProgress,
      levelCoins: {
        ..._progress.levelCoins,
        levelId: (_progress.levelCoins[levelId] ?? 0) + result.coinsAwarded,
      },
      responseScores: _progress.responseScores,
      stepTotals: {
        ..._progress.stepTotals,
        if (result.totalSteps > 0) levelId: result.totalSteps,
      },
    );
    _loaded = true;
    notifyListeners();
  }

  /// Folds a level completion into the snapshot immediately.
  void applyCompletion({
    required int levelId,
    required LevelCompletionResult result,
    int? responseScore,
  }) {
    _progress = LearningProgress(
      coins: result.totalCoins,
      completedLevelIds: {..._progress.completedLevelIds, ...result.completedLevelIds},
      levelProgress: _progress.levelProgress,
      levelCoins: {..._progress.levelCoins, levelId: result.levelCoins},
      responseScores: {
        ..._progress.responseScores,
        if (responseScore != null) levelId: responseScore,
      },
      stepTotals: _progress.stepTotals,
    );
    _loaded = true;
    notifyListeners();
  }

  /// Drops everything. Called on sign-out so the next account never sees the
  /// previous user's coins flash before the first refresh lands.
  void clear() {
    _progress = const LearningProgress.empty();
    _loaded = false;
    _stale = false;
    notifyListeners();
  }
}
