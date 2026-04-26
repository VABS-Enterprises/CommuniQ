import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/demo_evaluation_result.dart';
import 'package:communiq/models/onboarding_data.dart';

class OnboardingService {
  OnboardingService._();

  static const String _pendingKey = 'pending_onboarding';

  // ── Local storage ─────────────────────────────────────────────────────────

  static Future<void> saveLocally(OnboardingData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, data.toJsonString());
      debugPrint('');
      debugPrint('[Onboarding] ── Saved to SharedPreferences ─────────────');
      debugPrint('[Onboarding]   contexts      : ${data.contexts}');
      debugPrint('[Onboarding]   challenges    : ${data.challenges}');
      debugPrint('[Onboarding]   speakingStyle : ${data.speakingStyle ?? "—"}');
      debugPrint('[Onboarding]   speakingNote  : ${data.speakingNote ?? "—"}');
      debugPrint('[Onboarding]   level         : ${data.level ?? "—"}');
      debugPrint('[Onboarding]   primaryGoal   : ${data.primaryGoal ?? "—"}');
      debugPrint('[Onboarding] ─────────────────────────────────────────────');
      debugPrint('');
    } catch (e) {
      debugPrint('[Onboarding] ❌ saveLocally failed: $e');
    }
  }

  static Future<OnboardingData?> loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null) {
        debugPrint('[Onboarding] loadLocal → no pending data');
        return null;
      }
      final data = OnboardingData.fromJsonString(raw);
      debugPrint('[Onboarding] loadLocal → found pending data '
          '(contexts=${data.contexts.length}, '
          'challenges=${data.challenges.length}, '
          'goal=${data.primaryGoal ?? "none"})');
      return data;
    } catch (e) {
      debugPrint('[Onboarding] ❌ loadLocal failed: $e');
      return null;
    }
  }

  static Future<bool> hasPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pendingKey);
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
      debugPrint('[Onboarding] 🗑  Local pending data cleared');
    } catch (e) {
      debugPrint('[Onboarding] ❌ clearLocal failed: $e');
    }
  }

  // ── Server sync ───────────────────────────────────────────────────────────

  static Future<void> syncToServer(OnboardingData data) async {
    debugPrint('');
    debugPrint('[Onboarding] ── Syncing to Firestore ───────────────────────');
    debugPrint('[Onboarding]   POST ${ApiConstants.onboarding}');
    debugPrint('[Onboarding]   payload: ${data.toJson()}');
    try {
      final response =
          await ApiService.post(ApiConstants.onboarding, body: data.toJson());
      await clearLocal();
      debugPrint('[Onboarding] ✅ Firestore write confirmed');
      debugPrint('[Onboarding]   server response: $response');
      debugPrint('[Onboarding] ─────────────────────────────────────────────');
      debugPrint('');
    } catch (e) {
      debugPrint('[Onboarding] ⚠️  Sync failed — data kept locally for retry');
      debugPrint('[Onboarding]   error: $e');
      debugPrint('[Onboarding] ─────────────────────────────────────────────');
      debugPrint('');
    }
  }

  // ── Demo evaluation ───────────────────────────────────────────────────────

  /// Sends the user's typed self-introduction to the backend for AI evaluation.
  /// Unauthenticated — available before account creation.
  /// Throws on network/server errors; callers should handle and show UI feedback.
  static Future<DemoEvaluationResult> evaluateDemoIntro(
      String introduction) async {
    debugPrint('[Onboarding] Evaluating demo intro (${introduction.length} chars)');
    final response = await ApiService.post(
      ApiConstants.onboardingDemo,
      body: {'userIntroduction': introduction},
    );
    final result = DemoEvaluationResult.fromJson(response);
    debugPrint('[Onboarding] Demo eval complete — overall=${result.overallScore}');
    return result;
  }

  /// Uploads a WAV audio file to the backend and returns the Whisper transcript.
  /// Throws on network/server errors; callers should handle and show UI feedback.
  static Future<String> transcribeDemoAudio(String audioPath) async {
    debugPrint('[Onboarding] Uploading audio for Whisper transcription…');
    final filename = audioPath.split('/').last;
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioPath, filename: filename),
    });
    try {
      final response = await ApiService.instance.dio.post(
        ApiConstants.onboardingTranscribe,
        data: formData,
      );
      final text = (response.data as Map<String, dynamic>)['text'] as String;
      debugPrint('[Onboarding] Whisper transcript (${text.length} chars): '
          '"${text.substring(0, text.length.clamp(0, 80))}…"');
      return text;
    } on DioException catch (e) {
      // Extract the human-readable message from the server's JSON error body.
      final body = e.response?.data;
      String? serverMsg;
      if (body is Map) {
        serverMsg = (body['detail'] ?? body['error'])?.toString();
      }
      debugPrint('[Onboarding] Transcription error (${e.response?.statusCode}): $serverMsg');
      throw Exception(serverMsg ?? 'Transcription failed. Please try again.');
    }
  }

  static Future<void> syncPendingToServer() async {
    debugPrint('[Onboarding] Checking for pending onboarding data...');
    final data = await loadLocal();
    if (data == null) {
      debugPrint('[Onboarding] No pending data — nothing to sync');
      return;
    }
    await syncToServer(data);
  }
}
