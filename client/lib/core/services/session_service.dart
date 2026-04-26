import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/profile_cache_service.dart';
import 'package:communiq/models/scenario_model.dart';
import 'package:communiq/models/session_result_model.dart'
    show OpeningResult, SessionEndResult, TurnResult;
import 'package:communiq/models/user_profile.dart';

/// Handles all session-related API calls to the Node backend.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Dio get _dio => ApiService.instance.dio;

  // ─── Profile stream ────────────────────────────────────────────────────────

  /// Emits whenever the profile is refreshed from the network.
  /// Screens subscribe to this to update UI without re-fetching.
  final _profileController = StreamController<UserProfile>.broadcast();
  Stream<UserProfile> get profileUpdates => _profileController.stream;

  // ─── User profile ──────────────────────────────────────────────────────────

  /// Returns the cached profile immediately (zero latency), then fires a
  /// background network refresh.  If no cache exists, awaits the first fetch.
  ///
  /// Pattern: stale-while-revalidate.
  ///   - Cache hit  → return cached instantly; background refresh updates [profileUpdates].
  ///   - Cache miss → await network fetch, cache the result, return it.
  Future<UserProfile> fetchProfile() async {
    final cached = await ProfileCacheService.load();

    if (cached != null) {
      debugPrint('[SessionService] fetchProfile ← cache hit, refreshing in background');
      _refreshInBackground();
      return cached;
    }

    // No cache yet — must wait for the network.
    debugPrint('[SessionService] fetchProfile ← no cache, fetching from network');
    return _fetchFromNetwork();
  }

  /// Re-fetches the profile from the network, saves to cache, and pushes the
  /// result to [profileUpdates].  Silently swallows errors so background
  /// refreshes never crash the app.
  void _refreshInBackground() {
    _fetchFromNetwork().then((fresh) {
      ProfileCacheService.save(fresh);
      _profileController.add(fresh);
      debugPrint('[SessionService] background refresh ✓');
    }).catchError((e) {
      debugPrint('[SessionService] background refresh failed (silenced): $e');
    });
  }

  /// Forces a fresh network fetch (ignores cache).  Used by pull-to-refresh.
  /// Saves result to cache and pushes to [profileUpdates].
  Future<UserProfile> refreshProfile() async {
    final fresh = await _fetchFromNetwork();
    await ProfileCacheService.save(fresh);
    _profileController.add(fresh);
    return fresh;
  }

  /// Core network fetch: GET /user/profile + optional GET /sessions/history.
  Future<UserProfile> _fetchFromNetwork() async {
    try {
      debugPrint('[SessionService] _fetchFromNetwork →');

      final profileResponse = await _dio.get(ApiConstants.userProfile);
      final profileData =
          (profileResponse.data as Map<String, dynamic>?)?['user']
              as Map<String, dynamic>?;
      if (profileData == null) throw Exception('Profile data missing');

      // Session count is optional — a missing Firestore index or 5xx must not
      // prevent the profile from rendering.
      int completed = 0;
      try {
        final sessionsResponse = await _dio.get(ApiConstants.sessionsHistory);
        final sessions =
            (sessionsResponse.data as Map<String, dynamic>?)?['sessions']
                as List? ??
                [];
        completed = sessions
            .where((s) => (s as Map<String, dynamic>)['status'] == 'completed')
            .length;
      } catch (e) {
        debugPrint('[SessionService] sessions history failed (non-fatal): $e');
      }

      final profile =
          UserProfile.fromJson(profileData).copyWithSessions(completed);
      debugPrint('[SessionService] _fetchFromNetwork ✓  sessions=$completed');
      return profile;
    } on DioException catch (e) {
      debugPrint('[SessionService] _fetchFromNetwork ✗ DioException: $e');
      // Last-resort fallback to /auth/me (lighter endpoint, no skillProgress).
      try {
        final r = await _dio.get(ApiConstants.authMe);
        final d = (r.data as Map<String, dynamic>?)?['user']
            as Map<String, dynamic>?;
        if (d != null) return UserProfile.fromJson(d);
      } catch (_) {}
      throw Exception(_dioMessage(e, 'Could not load profile'));
    } catch (e) {
      debugPrint('[SessionService] _fetchFromNetwork ✗ $e');
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

  /// Creates a new session. Returns the sessionId.
  ///
  /// Provide [scenarioId] to use a Firestore-backed scenario, **or** provide
  /// [scenarioPrompt] (a plain-text system prompt) for a custom / preset session.
  /// At least one of the two must be non-empty.
  Future<String> startSession(
    String scenarioId, {
    String? scenarioPrompt,
    String? scenarioTitle,
    String? persona,
    String? tone,
    String? languageLevel,
    String? role,
    String? traits,
    String? backstory,
  }) async {
    assert(
      scenarioId.isNotEmpty || (scenarioPrompt != null && scenarioPrompt.isNotEmpty),
      'Provide either scenarioId or scenarioPrompt',
    );
    try {
      debugPrint('[SessionService] startSession → '
          '${scenarioId.isNotEmpty ? "scenarioId=$scenarioId" : "scenarioPrompt (custom)"} '
          'persona=$persona tone=$tone level=$languageLevel role=$role traits=$traits');
      final response = await _dio.post(
        ApiConstants.sessionsStart,
        data: {
          if (scenarioId.isNotEmpty) 'scenarioId': scenarioId,
          if (scenarioPrompt != null && scenarioPrompt.isNotEmpty)
            'scenarioPrompt': scenarioPrompt,
          if (scenarioTitle != null && scenarioTitle.isNotEmpty)
            'scenarioTitle': scenarioTitle,
          if (persona != null) 'persona': persona,
          if (tone != null) 'tone': tone,
          if (languageLevel != null) 'languageLevel': languageLevel,
          if (role != null && role.isNotEmpty) 'role': role,
          if (traits != null && traits.isNotEmpty) 'traits': traits,
          if (backstory != null && backstory.isNotEmpty) 'backstory': backstory,
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

  /// Fetches the first AI line + audio before any user recording (Colab parity).
  Future<OpeningResult> fetchOpening({required String sessionId}) async {
    try {
      debugPrint('[SessionService] fetchOpening → sessionId=$sessionId');
      final response = await _dio.post(
        ApiConstants.sessionsOpening,
        data: {'sessionId': sessionId},
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final result =
          OpeningResult.fromJson(response.data as Map<String, dynamic>);
      debugPrint('[SessionService] fetchOpening ✓');
      return result;
    } on DioException catch (e) {
      debugPrint('[SessionService] fetchOpening ✗ DioException: $e');
      throw Exception(_dioMessage(e, 'Could not load opening'));
    } catch (e) {
      debugPrint('[SessionService] fetchOpening ✗ $e');
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
