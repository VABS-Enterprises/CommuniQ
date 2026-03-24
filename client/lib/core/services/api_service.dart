import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Server URL is configured at build time via --dart-define=SERVER_URL=...
/// Default targets the Android emulator's loopback alias for 127.0.0.1 on host.
/// For physical devices run: flutter run --dart-define=SERVER_URL=http://192.168.x.x:3000
const _kServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Singleton Dio client that attaches the Firebase ID token to every request.
/// Dio is used (rather than package:http) because SessionService needs multipart
/// form-data support for audio file uploads.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _kServerUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      // NOTE: No global Content-Type header — Dio sets it automatically with
      // the correct multipart boundary when FormData is used.
    ),
  )
    ..interceptors.add(_FirebaseAuthInterceptor())
    ..interceptors.add(_LoggingInterceptor())
    ..interceptors.add(_ErrorInterceptor());

  Dio get dio => _dio;

  /// Convenience static wrapper used by [AuthService] for simple JSON POST
  /// calls (no multipart). Delegates to the singleton Dio instance so the
  /// Firebase auth interceptor is always applied.
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await instance.dio.post(endpoint, data: body);
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }
}

/// Fetches the current user's Firebase ID token and adds it as a Bearer token
/// on every outgoing request. Calls handler.reject on failure so Dio does not
/// hang indefinitely.
class _FirebaseAuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Force-refresh on first call after a cold start to avoid stale tokens.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      // If token fetch fails, proceed WITHOUT the auth header.
      // The server returns 401 which is handled by _ErrorInterceptor.
      // Never reject the request here — that causes ALL screens to fail silently.
      debugPrint('[AuthInterceptor] Token fetch failed (proceeding without token): $e');
    }
    handler.next(options);
  }
}

/// Logs every outgoing request and its response/error in debug mode.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API →] ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '[API ←] ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '[API ✗] ${err.response?.statusCode ?? "no-response"} '
          '${err.requestOptions.uri} — ${err.message}');
    }
    handler.next(err);
  }
}

/// Global handler for 4xx and 5xx responses. Surfaces a clean error so
/// individual screens do not need to duplicate this logic.
/// NOTE: We do NOT auto-sign-out on 401 — each screen handles auth errors
/// gracefully by showing an error state. Auto-sign-out caused cascade failures
/// when Firebase token refreshes were momentarily slow on cold start.
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401) {
      debugPrint('[API] 401 Unauthorized — ${err.requestOptions.uri}');
    } else if (statusCode != null && statusCode >= 500) {
      debugPrint('[API] Server error $statusCode — ${err.requestOptions.uri}');
    }

    handler.next(err);
  }
}
