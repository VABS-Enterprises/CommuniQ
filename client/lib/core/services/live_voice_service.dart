import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../constants/api_constants.dart';

/// Manages the LiveKit WebRTC room for one CommuniQ live voice session.
///
/// Lifecycle:
///   1. [connect] — fetch a LiveKit token from Node, join the room,
///      publish the mic, and subscribe to the AI audio track.
///   2. [dispose] — disconnect from the room and release resources.
///
/// The classic HTTP path (press-Send, upload WAV) is unchanged.
/// Live voice is opt-in: the conversation screen checks
/// [isLiveModeAvailable] before calling [connect].
///
/// Audio routing:
///   - Flutter publishes its mic as a LiveKit audio track.
///   - The Pipecat worker publishes the AI audio as a separate track.
///   - LiveKit handles mixing, jitter buffering, and TURN relay automatically.
///
/// Barge-in: Silero VAD in the Pipecat worker detects speech from Flutter
/// while the AI is playing — no additional Flutter code is needed.
class LiveVoiceService extends ChangeNotifier {
  final Dio _dio;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  LiveVoiceService(this._dio);

  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  Room? get room => _room;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Connect to the LiveKit room for [sessionId].
  ///
  /// Steps:
  ///   1. POST /sessions/livekit-token → { token, livekitUrl }
  ///   2. Room.connect(livekitUrl, token)
  ///   3. Publish local mic track
  ///   4. Listen for AI audio track from the Pipecat agent
  ///
  /// The Dio instance should already have the Firebase auth interceptor attached
  /// (use ApiService.instance.dio) so no explicit auth token is needed here.
  ///
  /// Throws [LiveVoiceException] on any failure so the conversation screen
  /// can fall back to classic HTTP mode gracefully.
  Future<void> connect(String sessionId) async {
    try {
      final livekitCreds = await _fetchToken(sessionId);
      final livekitUrl = livekitCreds['livekitUrl'] as String;
      final roomToken = livekitCreds['token'] as String;

      _room = Room(
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'user-mic',
          ),
        ),
      );
      _roomListener = _room!.createListener();

      await _room!.connect(livekitUrl, roomToken);

      // Publish local microphone.
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // Subscribe to AI audio tracks from remote participants (the Pipecat agent).
      _roomListener!.on<TrackSubscribedEvent>(_onTrackSubscribed);
      _roomListener!.on<TrackUnsubscribedEvent>(_onTrackUnsubscribed);
      _roomListener!.on<RoomDisconnectedEvent>(_onDisconnected);

      notifyListeners();
      debugPrint('[LiveVoice] Connected — session=$sessionId');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data?['error'] ?? e.message;
      throw LiveVoiceException(
        'Failed to get LiveKit token (HTTP $statusCode): $message',
      );
    } catch (e) {
      throw LiveVoiceException('LiveKit connection failed: $e');
    }
  }

  /// Disconnect from the room and release all resources.
  /// Safe to call multiple times.
  Future<void> disconnect() async {
    await _roomListener?.dispose();
    _roomListener = null;
    await _room?.disconnect();
    _room?.dispose();
    _room = null;
    notifyListeners();
    debugPrint('[LiveVoice] Disconnected');
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchToken(String sessionId) async {
    final resp = await _dio.post(
      ApiConstants.sessionsLivekitToken,
      data: jsonEncode({'sessionId': sessionId}),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return resp.data as Map<String, dynamic>;
  }

  void _onTrackSubscribed(TrackSubscribedEvent event) {
    if (event.track.kind == TrackType.AUDIO) {
      debugPrint(
        '[LiveVoice] AI audio track subscribed — participant=${event.participant.identity}',
      );
      // LiveKit SDK automatically routes subscribed audio tracks to the device
      // speaker. No manual AudioPlayer setup needed.
    }
  }

  void _onTrackUnsubscribed(TrackUnsubscribedEvent event) {
    debugPrint('[LiveVoice] Track unsubscribed — ${event.track.sid}');
  }

  void _onDisconnected(RoomDisconnectedEvent event) {
    debugPrint('[LiveVoice] Room disconnected — reason=${event.reason}');
    notifyListeners();
  }
}

/// Thrown when LiveKit connection or token fetch fails.
/// The conversation screen catches this and can fall back to classic HTTP.
class LiveVoiceException implements Exception {
  final String message;
  const LiveVoiceException(this.message);

  @override
  String toString() => 'LiveVoiceException: $message';
}
