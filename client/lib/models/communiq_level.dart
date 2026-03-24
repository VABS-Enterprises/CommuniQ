class CommuniqLevel {
  final int id;
  final String title;
  final String category;
  final List<CommuniqStage> stages;

  CommuniqLevel({
    required this.id,
    required this.title,
    required this.category,
    required this.stages,
  });

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    return CommuniqLevel(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      stages: (json['stages'] as List<dynamic>)
          .map((s) => CommuniqStage.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'stages': stages.map((s) => s.toJson()).toList(),
    };
  }
}

class CommuniqStage {
  final int stage;
  final String difficulty;
  final String scenario;
  final String prompt;

  CommuniqStage({
    required this.stage,
    required this.difficulty,
    required this.scenario,
    required this.prompt,
  });

  factory CommuniqStage.fromJson(Map<String, dynamic> json) {
    return CommuniqStage(
      stage: json['stage'] as int,
      difficulty: json['difficulty'] as String,
      scenario: json['scenario'] as String,
      prompt: json['prompt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'difficulty': difficulty,
      'scenario': scenario,
      'prompt': prompt,
    };
  }
}
