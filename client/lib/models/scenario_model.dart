/// Maps a single scenario document returned by GET /scenarios.
class ScenarioModel {
  final String scenarioId;
  final String title;
  final String description;
  final String type; // hr_interview | gd | sales | technical
  final int difficulty; // 1–5
  final int requiredLevel;
  final List<String> tags;

  const ScenarioModel({
    required this.scenarioId,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.requiredLevel,
    required this.tags,
  });

  factory ScenarioModel.fromJson(Map<String, dynamic> json) {
    return ScenarioModel(
      scenarioId: json['scenarioId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Scenario',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      requiredLevel: (json['requiredLevel'] as num?)?.toInt() ?? 1,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  /// Human-readable label for the scenario type.
  String get typeLabel {
    switch (type) {
      case 'hr_interview':
        return 'HR Interview';
      case 'technical':
        return 'Technical Interview';
      case 'gd':
        return 'Group Discussion';
      case 'sales':
        return 'Sales Call';
      default:
        return type;
    }
  }

  /// Difficulty as a word (1=Easy … 5=Nightmare).
  String get difficultyLabel {
    const labels = ['', 'Easy', 'Medium', 'Hard', 'Expert', 'Nightmare'];
    return difficulty < labels.length ? labels[difficulty] : 'Hard';
  }
}
