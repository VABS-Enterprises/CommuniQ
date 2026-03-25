import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/models/scenario_model.dart';
import 'package:communiq/models/session_result_model.dart';
import 'package:communiq/models/user_profile.dart';

/// Handles all session-related API calls to the Node backend.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Dio get _dio => ApiService.instance.dio;

  // ─── User profile ──────────────────────────────────────────────────────────

  /// Fetches the current user's Firestore profile from GET /auth/me.
  Future<UserProfile> fetchProfile() async {
    try {
      debugPrint('[SessionService] fetchProfile →');
      final response = await _dio.get(ApiConstants.authMe);
      final data = (response.data as Map<String, dynamic>?)?['user']
          as Map<String, dynamic>?;
      if (data == null) throw Exception('Profile data missing in response');
      debugPrint('[SessionService] fetchProfile ✓');
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[SessionService] fetchProfile ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not load profile'));
    } catch (e) {
      debugPrint('[SessionService] fetchProfile ✗ $e');
      rethrow;
    }
  }

  // ─── Scenarios ─────────────────────────────────────────────────────────────

  /// Fetches the list of scenarios available to the current user's level.
  Future<List<ScenarioModel>> fetchScenarios() async {
    try {
      debugPrint('[SessionService] fetchScenarios →');
      final response = await _dio.get(ApiConstants.scenarios);
      final raw =
          (response.data as Map<String, dynamic>?)?['scenarios'] as List? ?? [];
      debugPrint('[SessionService] fetchScenarios ✓ (${raw.length} items)');
      return raw
          .map((e) => ScenarioModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[SessionService] fetchScenarios ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not load scenarios'));
    } catch (e) {
      debugPrint('[SessionService] fetchScenarios ✗ $e');
      rethrow;
    }
  }

  // ─── Session lifecycle ─────────────────────────────────────────────────────

  /// Creates a new session for the given scenario. Returns the sessionId.
  /// Optionally sends [persona], [tone], and [languageLevel] so the backend
  /// can inject them into the AI system prompt.
  Future<String> startSession(
    String scenarioId, {
    String? persona,
    String? tone,
    String? languageLevel,
  }) async {
    try {
      debugPrint('[SessionService] startSession → scenarioId=$scenarioId '
          'persona=$persona tone=$tone level=$languageLevel');
      final response = await _dio.post(
        ApiConstants.sessionsStart,
        data: {
          'scenarioId': scenarioId,
          if (persona != null) 'persona': persona,
          if (tone != null) 'tone': tone,
          if (languageLevel != null) 'languageLevel': languageLevel,
        },
      );
      final sessionId =
          (response.data as Map<String, dynamic>?)?['sessionId'] as String?;
      if (sessionId == null) throw Exception('sessionId missing in response');
      debugPrint('[SessionService] startSession ✓ sessionId=$sessionId');
      return sessionId;
    } on DioException catch (e) {
      debugPrint('[SessionService] startSession ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not start session'));
    } catch (e) {
      debugPrint('[SessionService] startSession ✗ $e');
      rethrow;
    }
  }

  /// Sends one conversation turn (audio bytes + history) to the Node server.
  /// Returns the AI's text reply, the user's transcription, and the AI's
  /// base64-encoded MP3 audio.
  Future<TurnResult> processTurn({
    required String sessionId,
    required Uint8List audioBytes,
    required String filename,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      debugPrint('[SessionService] processTurn → sessionId=$sessionId, '
          'file=$filename (${audioBytes.length}B)');

      final formData = FormData.fromMap({
        'audioFile': MultipartFile.fromBytes(
          audioBytes,
          filename: filename,
          contentType: DioMediaType.parse(_mimeFromFilename(filename)),
        ),
        'sessionId': sessionId,
        'conversationHistory': _encodeHistory(conversationHistory),
      });

      // Do NOT set contentType in Options — Dio auto-sets multipart/form-data
      // with the correct boundary when FormData is passed as data.
      // sendTimeout covers the audio upload; 120 s handles recordings up to
      // ~4 min at the default 16 kHz / mono / WAV bitrate (~256 kbps).
      final response = await _dio.post(
        ApiConstants.sessionsTurn,
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          // 120 s: 90 s Node→AI timeout + 30 s buffer for cold-start wake-up on
          // Render's free tier (services spin down after 15 min of inactivity).
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      final result =
          TurnResult.fromJson(response.data as Map<String, dynamic>);
      debugPrint('[SessionService] processTurn ✓');
      return result;
    } on DioException catch (e) {
      debugPrint('[SessionService] processTurn ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Turn processing failed'));
    } catch (e) {
      debugPrint('[SessionService] processTurn ✗ $e');
      rethrow;
    }
  }

  /// Abandons a session without evaluation. Used when the user backs out of
  /// the conversation screen mid-session.
  Future<void> abandonSession(String sessionId) async {
    try {
      debugPrint('[SessionService] abandonSession → sessionId=$sessionId');
      await _dio.post(
        ApiConstants.sessionsAbandon,
        data: {'sessionId': sessionId},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      debugPrint('[SessionService] abandonSession ✓');
    } on DioException catch (e) {
      debugPrint('[SessionService] abandonSession ✗ DioException: $e');
    } catch (e) {
      debugPrint('[SessionService] abandonSession ✗ $e');
    }
  }

  /// Ends the session and triggers AI evaluation. Returns scores, XP, level.
  Future<SessionEndResult> endSession(String sessionId) async {
    try {
      debugPrint('[SessionService] endSession → sessionId=$sessionId');
      final response = await _dio.post(
        ApiConstants.sessionsEnd,
        data: {'sessionId': sessionId},
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      final result =
          SessionEndResult.fromJson(response.data as Map<String, dynamic>);
      debugPrint('[SessionService] endSession ✓');
      return result;
    } on DioException catch (e) {
      debugPrint('[SessionService] endSession ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not end session'));
    } catch (e) {
      debugPrint('[SessionService] endSession ✗ $e');
      rethrow;
    }
  }

  // ─── Session history ───────────────────────────────────────────────────────

  /// Returns a list of the user's past sessions from GET /sessions/history.
  Future<List<Map<String, dynamic>>> fetchSessionHistory() async {
    try {
      debugPrint('[SessionService] fetchSessionHistory →');
      final response = await _dio.get(ApiConstants.sessionsHistory);
      final raw =
          (response.data as Map<String, dynamic>?)?['sessions'] as List? ?? [];
      debugPrint(
          '[SessionService] fetchSessionHistory ✓ (${raw.length} items)');
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      debugPrint('[SessionService] fetchSessionHistory ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not load session history'));
    } catch (e) {
      debugPrint('[SessionService] fetchSessionHistory ✗ $e');
      rethrow;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _mimeFromFilename(String filename) {
    final parts = filename.split('.');
    final ext = parts.length > 1 ? parts.last.toLowerCase() : '';
    const map = {
      'wav': 'audio/wav',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'webm': 'audio/webm',
    };
    return map[ext] ?? 'audio/wav';
  }

  String _encodeHistory(List<Map<String, String>> history) =>
      jsonEncode(history);

  /// Extracts a readable message from a [DioException], falling back to
  /// [fallback] if nothing more informative is available.
  String _dioMessage(DioException e, String fallback) {
    final body = e.response?.data as Map<String, dynamic>?;
    // Node returns { "error": "..." }; FastAPI returns { "detail": "..." }
    final serverMsg = (body?['error'] ?? body?['detail'] ?? body?['message']) as String?;
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
    return fallback;
  }
}
