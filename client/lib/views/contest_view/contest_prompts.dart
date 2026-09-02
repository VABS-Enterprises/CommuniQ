import 'package:communiq/models/contest_models.dart';

/// Prompts the user speaks or writes to.
///
/// Content, not configuration — it lives in the client the same way the
/// roleplay scenario prompts do. The server accepts `motion` as free text, so
/// adding or changing prompts here needs no backend change.
const Map<ContestType, List<String>> kContestPrompts = {
  ContestType.debate: [
    'Remote work should be the default for knowledge jobs.',
    'Social media does more harm than good to public discourse.',
    'AI should be regulated like medicine before public release.',
    'Standardised exams are a fair measure of ability.',
    'Companies should publish every employee salary.',
  ],
  ContestType.gd: [
    'How should India prepare its workforce for AI?',
    'Is a four-day work week practical for Indian startups?',
    'Should college education be free for everyone?',
    'What matters more in hiring: skills or degrees?',
    'How do we make cities more liveable in the next decade?',
  ],
  ContestType.extempore: [
    'A time you changed your mind about something important.',
    'The most useful piece of feedback you ever received.',
    'If you had to teach one skill to everyone, what would it be?',
    'A decision you would make differently today.',
    'What does good communication look like under pressure?',
  ],
  ContestType.quiz: [
    'Explain the difference between correlation and causation.',
    'How would you describe an API to a non-technical stakeholder?',
    'What makes feedback actionable rather than vague?',
    'Explain compound interest to a ten-year-old.',
    'What is the difference between a goal and a system?',
  ],
};

/// Picks a prompt that changes daily, so the contest feels fresh without
/// needing server-side scheduling.
String promptFor(ContestType type, {DateTime? now}) {
  final list = kContestPrompts[type] ?? const [];
  if (list.isEmpty) return '';
  final day = (now ?? DateTime.now()).difference(DateTime(2024)).inDays;
  return list[day % list.length];
}

/// Debate is the only format where a side has to be picked.
const kDebatePositions = ['for', 'against'];
