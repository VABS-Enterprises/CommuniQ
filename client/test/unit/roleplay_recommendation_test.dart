import 'package:flutter_test/flutter_test.dart';

import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/models/session_result_model.dart';

void main() {
  group('presetKeyForRecommendation', () {
    test('strips the evaluator level suffix', () {
      expect(presetKeyForRecommendation('job_interview_intermediate'),
          'job_interview');
      expect(presetKeyForRecommendation('negotiation_advanced'), 'negotiation');
      expect(presetKeyForRecommendation('small_talk_beginner'), 'small_talk');
      expect(presetKeyForRecommendation('conflict_hard'), 'conflict');
    });

    test('every preset key resolves, bare and with each level', () {
      for (final p in kScenarioPresets) {
        expect(presetKeyForRecommendation(p.key), p.key);
        for (final level in ['beginner', 'intermediate', 'advanced']) {
          expect(presetKeyForRecommendation('${p.key}_$level'), p.key);
        }
      }
    });

    test('tolerates case, spaces and hyphens', () {
      expect(presetKeyForRecommendation(' Job-Interview_Advanced '),
          'job_interview');
      expect(presetKeyForRecommendation('Group Discussion'), 'feedback');
    });

    test('maps legacy scenario types', () {
      expect(presetKeyForRecommendation('hr_interview'), 'job_interview');
      expect(presetKeyForRecommendation('hr_interview_beginner'),
          'job_interview');
      expect(presetKeyForRecommendation('sales'), 'negotiation');
      expect(presetKeyForRecommendation('sales_intermediate'), 'negotiation');
      expect(presetKeyForRecommendation('gd'), 'feedback');
      expect(presetKeyForRecommendation('gd_advanced'), 'feedback');
    });

    test('unknown or empty values return null', () {
      expect(presetKeyForRecommendation(null), isNull);
      expect(presetKeyForRecommendation(''), isNull);
      expect(presetKeyForRecommendation('   '), isNull);
      expect(presetKeyForRecommendation('general_intermediate'), isNull);
      expect(presetKeyForRecommendation('underwater_basket_weaving'), isNull);
      expect(presetKeyForRecommendation('_intermediate'), isNull);
    });

    test('result always names a real preset', () {
      for (final raw in ['job_interview_intermediate', 'sales', 'gd']) {
        expect(presetForKey(presetKeyForRecommendation(raw)), isNotNull);
      }
    });
  });

  group('recommendationLevel', () {
    test('extracts the difficulty word', () {
      expect(recommendationLevel('negotiation_advanced'), 'advanced');
      expect(recommendationLevel('job_interview_intermediate'), 'intermediate');
      expect(recommendationLevel('negotiation'), isNull);
      expect(recommendationLevel(null), isNull);
    });
  });

  group('stored report → SessionReport', () {
    test('maps a GET /sessions/:id/report payload', () {
      final report = SessionReport.fromJson({
        'scores': {
          'clarity': 80,
          'fluency': 70,
          'confidence': 60,
          'vocabulary': 90,
          'grammar': 50,
        },
        'fillerWordCount': 2,
        'fillerWords': ['um', 'like'],
        'strengths': ['Clear structure'],
        'improvements': ['Slow down'],
        'recommendedNextType': 'job_interview_intermediate',
        'rawTranscript': 'User: hi\nAI: hello',
        'scenarioType': 'job_interview',
        'generatedAt': '2026-10-01T10:00:00.000Z',
      });
      final config = report.toFeedbackConfig('Job Interview');
      expect(config.overallScore, 70);
      expect(config.scenarioTitle, 'Job Interview');
      expect(config.improvements, ['Slow down']);
      expect(presetKeyForRecommendation(report.recommendedNextType),
          'job_interview');
    });
  });
}
