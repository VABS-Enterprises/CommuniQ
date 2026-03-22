import 'dart:convert';

class PersonaModel {
  final String id;
  final String name;
  final String description;
  final bool isCustom;
  final String tone;

  PersonaModel({
    required this.id,
    required this.name,
    required this.description,
    this.isCustom = false,
    this.tone = 'Neutral',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isCustom': isCustom,
      'tone': tone,
    };
  }

  factory PersonaModel.fromJson(Map<String, dynamic> json) {
    return PersonaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      isCustom: json['isCustom'] as bool? ?? false,
      tone: json['tone'] as String? ?? 'Neutral',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PersonaModel.fromJsonString(String source) => 
      PersonaModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
