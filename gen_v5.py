import json

journeys = [
    {'id': 1, 'title': 'Social Foundations', 'level_range': '1-10'},
    {'id': 2, 'title': 'Everyday Conversations', 'level_range': '11-20'},
    {'id': 3, 'title': 'Expressing Yourself', 'level_range': '21-30'},
    {'id': 4, 'title': 'Workplace Basics', 'level_range': '31-40'},
    {'id': 5, 'title': 'Active Listening & Empathy', 'level_range': '41-50'},
    {'id': 6, 'title': 'Navigating Disagreements', 'level_range': '51-60'},
    {'id': 7, 'title': 'Professional Presence', 'level_range': '61-70'},
    {'id': 8, 'title': 'Influence & Persuasion', 'level_range': '71-80'},
    {'id': 9, 'title': 'Leadership Communication', 'level_range': '81-90'},
    {'id': 10, 'title': 'Difficult Conversations', 'level_range': '91-100'},
    {'id': 11, 'title': 'Public Speaking Mastery', 'level_range': '101-110'},
    {'id': 12, 'title': 'High-Stakes Negotiation', 'level_range': '111-120'},
    {'id': 13, 'title': 'Crisis & Pressure Communication', 'level_range': '121-130'},
    {'id': 14, 'title': 'Emotional Intelligence in Action', 'level_range': '131-140'},
    {'id': 15, 'title': 'Executive Presence', 'level_range': '141-150'},
]

def mcq(step, q, correct, wrong, cf, inf):
    return {'step': step, 'question': q, 'correct_option': correct,
            'incorrect_options': wrong, 'correct_feedback': cf, 'incorrect_feedback': inf}

def resp(prompt, success):
    return {'prompt': prompt, 'success_feedback': success}

levels = []
# APPEND_HERE

output = {
    'app': 'CommuniQ',
    'version': '5.0',
    'total_levels': 150,
    'journeys': journeys,
    'levels': levels,
}

with open('communiq_levels_v5.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f'Generated {len(levels)} levels. Valid: {len(levels) == 150}')
