/// A single learning scenario in the CommuniQ journey.
/// Maps directly to one entry in communiq_levels_v3.json.
/// The internal _difficulty field from the JSON is intentionally
/// excluded — difficulty is never shown to the user in the UI.
class CommuniqLevel {
  final int id;
  final String title;
  final String category;
  final String scenario;
  final String prompt;

  const CommuniqLevel({
    required this.id,
    required this.title,
    required this.category,
    required this.scenario,
    required this.prompt,
  });

  factory CommuniqLevel.fromJson(Map<String, dynamic> json) {
    return CommuniqLevel(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      scenario: json['scenario'] as String,
      prompt: json['prompt'] as String,
      // _difficulty intentionally ignored
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'scenario': scenario,
      'prompt': prompt,
    };
  }

  /// XP reward per completed scenario (fixed for now, can be dynamic later)
  int get xpReward => 20;

  /// Icon emoji representing the category — used in UI nodes
  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'social':
        return '🗣️';
      case 'professional':
        return '💼';
      case 'communication':
        return '💬';
      case 'leadership':
        return '🌟';
      default:
        return '✨';
    }
  }
}
