import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('../communiq_levels_v4.json');
  final String jsonString = await file.readAsString();
  final Map<String, dynamic> data = jsonDecode(jsonString);

  final List<dynamic> levels = data['levels'];

  final StringBuffer buffer = StringBuffer();
  buffer.writeln("import 'package:communiq/models/communiq_level.dart';");
  buffer.writeln("");
  buffer.writeln("/// Static data source for all 150 CommuniQ learning scenarios.");
  buffer.writeln("/// Sourced from communiq_levels_v4.json.");
  buffer.writeln("class StaticLevels {");
  buffer.writeln("  StaticLevels._();");
  buffer.writeln("");
  buffer.writeln("  static const List<CommuniqLevel> allLevels = [");

  for (final level in levels) {
    final mcq = level['mcq'] ?? {};
    final response = level['response'] ?? {};
    
    // Helper to safely escape strings for Dart — uses double-quoted strings
    // so apostrophes (don't, you've, etc.) never need escaping.
    String escape(String? s) {
      if (s == null) return '""';
      // Only need to escape backslashes, double-quotes, and newlines inside "..."
      final escaped = s
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n');
      return '"$escaped"';
    }

    final incorrectOptions = List<String>.from(mcq['incorrect_options'] ?? []).map((o) => escape(o)).join(', ');

    buffer.writeln("    CommuniqLevel(");
    buffer.writeln("      id: ${level['id']},");
    buffer.writeln("      journeyId: ${level['journey_id'] ?? 1},");
    buffer.writeln("      journeyTitle: ${escape(level['journey_title'])},");
    buffer.writeln("      title: ${escape(level['title'])},");
    buffer.writeln("      scenario: ${escape(level['scenario'])},");
    buffer.writeln("      mcqQuestion: ${escape(mcq['question'])},");
    buffer.writeln("      mcqCorrectOption: ${escape(mcq['correct_option'])},");
    buffer.writeln("      mcqIncorrectOptions: [$incorrectOptions],");
    buffer.writeln("      mcqCorrectFeedback: ${escape(mcq['correct_feedback'])},");
    buffer.writeln("      mcqIncorrectFeedback: ${escape(mcq['incorrect_feedback'])},");
    buffer.writeln("      responsePrompt: ${escape(response['prompt'])},");
    buffer.writeln("      responseSuccessFeedback: ${escape(response['success_feedback'])},");
    buffer.writeln("    ),");
  }

  buffer.writeln("  ];");
  buffer.writeln("}");

  final outFile = File('lib/core/data/static_levels.dart');
  await outFile.writeAsString(buffer.toString());
  print('Successfully generated lib/core/data/static_levels.dart');
}
