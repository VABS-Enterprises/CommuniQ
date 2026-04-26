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

  /// Path to the local illustration for this scenario.
  String get imageAsset {
    final slug = title.toLowerCase().replaceAll(' ', '_').replaceAll('?', '').replaceAll('&', 'and');
    // Map specific titles to our saved file names
    if (slug.contains('introduce')) return 'assets/images/scenarios/introduce_yourself.png';
    if (slug.contains('strengths')) return 'assets/images/scenarios/strengths_weaknesses.png';
    if (slug.contains('hire_you')) return 'assets/images/scenarios/why_hire_you.png';
    if (slug.contains('technical')) return 'assets/images/scenarios/technical_solving.png';
    if (slug.contains('complex')) return 'assets/images/scenarios/complex_concept.png';
    if (slug.contains('sales_pitch')) return 'assets/images/scenarios/sales_pitch.png';
    if (slug.contains('cold_call')) return 'assets/images/scenarios/cold_call.png';
    if (slug.contains('group_discussion')) return 'assets/images/scenarios/gd_ai.png';
    if (slug.contains('salary')) return 'assets/images/scenarios/salary_negotiation.png';
    if (slug.contains('difficult_client')) return 'assets/images/scenarios/difficult_client.png';

    return 'assets/images/scenarios/introduce_yourself.png'; // Fallback
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
