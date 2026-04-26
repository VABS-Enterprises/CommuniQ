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

  /// Returns the standardized path for the premium level illustration.
  /// For now, we reuse the existing V2 circular assets deterministically based on ID
  /// so that all 150 levels have a premium illustration.
  String get imageAsset {
    final images = [
      'assets/images/scenarios/introduce_yourself.png',
      'assets/images/scenarios/job_interview_v2.png',
      'assets/images/scenarios/negotiation_v2.png',
      'assets/images/scenarios/technical_solving.png',
      'assets/images/scenarios/sales_pitch.png',
      'assets/images/scenarios/complex_concept.png',
      'assets/images/scenarios/difficult_client_v2.png',
      'assets/images/scenarios/gd_ai.png',
      'assets/images/scenarios/salary_negotiation.png',
      'assets/images/scenarios/strengths_weaknesses.png',
      'assets/images/scenarios/why_hire_you.png',
    ];
    
    // Use the exact image if title matches roughly
    final t = title.toLowerCase();
    if (t.contains('interview')) return 'assets/images/scenarios/job_interview_v2.png';
    if (t.contains('negotiat')) return 'assets/images/scenarios/negotiation_v2.png';
    if (t.contains('solving') || t.contains('technical')) return 'assets/images/scenarios/technical_solving.png';
    if (t.contains('pitch') || t.contains('sell')) return 'assets/images/scenarios/sales_pitch.png';
    if (t.contains('introduce')) return 'assets/images/scenarios/introduce_yourself.png';
    if (t.contains('concept') || t.contains('explain')) return 'assets/images/scenarios/complex_concept.png';
    
    // Otherwise deterministically cycle through the premium images
    final index = id % images.length;
    return images[index];
  }

  /// Icon emoji representing the category — used in UI as a fallback.
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
