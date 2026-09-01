import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';

/// One practice scenario the user can launch.
///
/// The system prompt is deliberately baked into the client rather than fetched:
/// starting a session needs no Firestore round-trip, and the Node backend
/// stores whatever is sent as the session's `customSystemPrompt`.
class ScenarioPreset {
  const ScenarioPreset({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.image,
    required this.color,
    required this.systemPrompt,
    required this.persona,
    required this.tone,
    required this.level,
    required this.role,
    required this.traits,
  });

  /// Stable identifier. Passed between screens to prefill the setup page, so
  /// it must match exactly — an unknown key silently prefills nothing.
  final String key;

  final String title;
  final String subtitle;
  final IconData icon;
  final String image;
  final Color color;

  final String systemPrompt;
  final String persona;
  final String tone;
  final String level;
  final String role;
  final String traits;
}

/// The single source of truth for practice scenarios.
///
/// Previously this list existed three times — in setup_scenario_page (7
/// entries), categories_section (4) and all_scenarios_page (4) — and they had
/// drifted apart. `assertiveness` was titled "Technical Solving" in two places
/// and "Technical Problem" in the third, and the Sales Pitch tile in
/// categories_section carried key `sales_pitch`, which matches no preset at
/// all, so choosing it from the Practise tab prefilled nothing. Three of the
/// seven scenarios were also undiscoverable from the "All scenarios" grid.
const List<ScenarioPreset> kScenarioPresets = [
  ScenarioPreset(
    key: 'job_interview',
    title: 'Job Interview',
    subtitle: 'Answer tough HR questions',
    icon: Icons.work_outline_rounded,
    image: 'assets/images/scenarios/introduce_yourself.png',
    color: AppColors.info,
    systemPrompt:
        'You are an experienced HR interviewer conducting a job interview for a mid-to-senior '
        'position at a reputable Indian tech company. Ask behavioral and situational questions '
        'using the STAR framework. Be professional and curious. Follow up on vague or incomplete '
        'answers — push gently for specifics. Occasionally challenge weak answers to see if the '
        'candidate can handle pressure.',
    persona: 'Friendly HR',
    tone: 'Professional',
    level: 'Hard',
    role: 'You as Candidate',
    traits: 'Logical',
  ),
  ScenarioPreset(
    key: 'negotiation',
    title: 'Negotiation',
    subtitle: 'Negotiate a raise or budget',
    icon: Icons.handshake_rounded,
    image: 'assets/images/scenarios/salary_negotiation.png',
    color: AppColors.success,
    systemPrompt:
        'You are a skeptical department head being approached for a salary raise or budget '
        'increase. You are not hostile, but you need solid justification — data, outcomes, '
        'market benchmarks. Challenge weak arguments respectfully. If presented with strong '
        'evidence and clear business impact, acknowledge it and show willingness to consider '
        'the request.',
    persona: 'Strict Manager',
    tone: 'Neutral',
    level: 'Hard',
    role: 'You as Employee',
    traits: 'Assertive',
  ),
  ScenarioPreset(
    key: 'assertiveness',
    title: 'Technical Solving',
    subtitle: 'Master technical logic problems',
    icon: Icons.code_rounded,
    image: 'assets/images/scenarios/technical_solving.png',
    color: AppColors.coral,
    systemPrompt:
        'You are a senior technical lead. Present a complex architectural or logical problem '
        'and ask the user to explain their approach. Be helpful but probe for edge cases. '
        'The user needs to practice explaining technical trade-offs clearly and logically.',
    persona: 'Strict Manager',
    tone: 'Professional',
    level: 'Medium',
    role: 'You as Employee',
    traits: 'Assertive',
  ),
  ScenarioPreset(
    key: 'small_talk',
    title: 'Sales Pitch',
    subtitle: 'Pitch your product to a client',
    icon: Icons.record_voice_over_rounded,
    image: 'assets/images/scenarios/sales_pitch.png',
    color: AppColors.grape,
    systemPrompt:
        'You are a potential enterprise client. The user is pitching a new software solution. '
        'Listen to their pitch, ask about ROI, and raise one common objection. See how the '
        'user handles persuasion and objection management.',
    persona: 'Strict Manager',
    tone: 'Neutral',
    level: 'Medium',
    role: 'You as Speaker',
    traits: 'Logical',
  ),
  ScenarioPreset(
    key: 'leadership',
    title: 'Explain a Concept',
    subtitle: 'Simplify complex technical ideas',
    icon: Icons.lightbulb_outline_rounded,
    image: 'assets/images/scenarios/complex_concept.png',
    color: AppColors.teal,
    systemPrompt:
        'You are a non-technical project stakeholder. Ask the user to explain a technical '
        'innovation or architecture. If they use too much jargon, ask for simplification. '
        'Focus on how clearly they can communicate value to a non-technical audience.',
    persona: 'Friendly Colleague',
    tone: 'Friendly',
    level: 'Medium',
    role: 'You as Manager',
    traits: 'Emotional',
  ),
  ScenarioPreset(
    key: 'feedback',
    title: 'Group Discussion',
    subtitle: 'Debate AI trends with a panel',
    icon: Icons.groups_rounded,
    image: 'assets/images/scenarios/gd_ai.png',
    color: AppColors.sun,
    systemPrompt:
        'You are a participant in a group discussion about the future of AI. '
        'Help the user practice turn-taking, building on others arguments, and '
        'presenting structured viewpoints in a high-pressure corporate setting.',
    persona: 'Friendly Colleague',
    tone: 'Neutral',
    level: 'Medium',
    role: 'You as Manager',
    traits: 'Emotional',
  ),
  ScenarioPreset(
    key: 'conflict',
    title: 'Conflict Resolution',
    subtitle: 'Handle a difficult client escalation',
    icon: Icons.balance_rounded,
    image: 'assets/images/scenarios/difficult_client.png',
    color: AppColors.error,
    systemPrompt:
        'You are an upset client whose project was delayed. You are demanding an explanation. '
        'The user needs to practice de-escalation, show empathy, and offer a professional '
        'remedy without promising more than can be delivered.',
    persona: 'Angry Client',
    tone: 'Aggressive',
    level: 'Hard',
    role: 'You as Manager',
    traits: 'Emotional',
  ),
];

/// Looks up a preset by [key]. Returns null for an unknown key so callers can
/// fall back to an unconfigured session rather than crashing.
ScenarioPreset? presetForKey(String? key) {
  if (key == null) return null;
  for (final p in kScenarioPresets) {
    if (p.key == key) return p;
  }
  return null;
}
