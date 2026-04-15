/// Shared mutable state for the Contest system.
/// Passed by reference so ContestPage and ContestResultPage stay in sync.
class ContestState {
  bool hasAttempted;
  int rank;
  int bestScore;
  int xpEarned;
  List<ContestAttempt> attempts;
  List<ContestHistory> history;

  ContestState({
    this.hasAttempted = false,
    this.rank = 24,
    this.bestScore = 0,
    this.xpEarned = 0,
    List<ContestAttempt>? attempts,
    List<ContestHistory>? history,
  })  : attempts = attempts ?? [],
        history = history ?? _defaultHistory();

  static List<ContestHistory> _defaultHistory() => [
        ContestHistory(name: 'Interview Challenge', rank: 12, bestScore: 82),
        ContestHistory(name: 'Negotiation Week', rank: 30, bestScore: 65),
        ContestHistory(name: 'Public Speaking', rank: 8, bestScore: 90),
      ];

  /// Called after a roleplay completes with a new score.
  void recordAttempt(int score) {
    hasAttempted = true;
    final num = attempts.length + 1;
    final isBest = score > bestScore;
    if (isBest) bestScore = score;
    // Simulate rank improvement on better score
    if (isBest && rank > 1) rank = (rank - 2).clamp(1, 100);
    xpEarned += 50;
    attempts.add(ContestAttempt(number: num, score: score, isBest: isBest));
    // Mark only latest best
    for (int i = 0; i < attempts.length; i++) {
      attempts[i] = ContestAttempt(
        number: attempts[i].number,
        score: attempts[i].score,
        isBest: attempts[i].score == bestScore,
      );
    }
  }
}

class ContestAttempt {
  final int number;
  final int score;
  final bool isBest;
  const ContestAttempt({
    required this.number,
    required this.score,
    required this.isBest,
  });
}

class ContestHistory {
  final String name;
  final int rank;
  final int bestScore;
  const ContestHistory({
    required this.name,
    required this.rank,
    required this.bestScore,
  });
}

/// Full leaderboard data (static mock — replace with API later)
final List<Map<String, dynamic>> kLeaderboard = [
  {'name': 'Alex', 'score': 92},
  {'name': 'Priya', 'score': 89},
  {'name': 'Rahul', 'score': 87},
  {'name': 'Sneha', 'score': 83},
  {'name': 'Dev', 'score': 81},
  {'name': 'Aisha', 'score': 80},
  {'name': 'Omar', 'score': 79},
  {'name': 'You', 'score': 78},
  {'name': 'Riya', 'score': 74},
  {'name': 'Arjun', 'score': 70},
];
