import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:communiq/core/services/offline_cache_service.dart';

/// Resolves the backend URL at runtime.
///
/// Priority:
///   1. --dart-define=SERVER_URL=... (build-time override, e.g. for staging/prod)
///   2. Debug: Android emulator  → http://10.0.2.2:3000
///             iOS simulator     → http://localhost:3000
///   3. Release → production cloud backend
String _resolveServerUrl() {
  const defined = String.fromEnvironment('SERVER_URL');
  if (defined.isNotEmpty) return defined;
  if (kDebugMode) {
    return 'http://localhost:3000';
  }
  return 'https://communiq.onrender.com';
}

/// Singleton Dio client that attaches the Firebase ID token to every request.
/// Dio is used (rather than package:http) because SessionService needs multipart
/// form-data support for audio file uploads.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _resolveServerUrl(),
      // 90 s: Render free-tier Node server can take 50–80 s to cold-start.
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
    ),
  )
    ..interceptors.add(_FirebaseAuthInterceptor())
    ..interceptors.add(_LoggingInterceptor())
    // Before _ErrorInterceptor: a replayed cache hit should resolve the call
    // rather than travel on as an error.
    ..interceptors.add(_OfflineCacheInterceptor())
    ..interceptors.add(_ErrorInterceptor());

  Dio get dio => _dio;

  /// Convenience static wrapper for simple JSON POST calls.
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

  /// Convenience static wrapper for simple JSON GET calls.
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await instance.dio.get(endpoint);
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  /// Convenience static wrapper for simple JSON PATCH calls.
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await instance.dio.patch(endpoint, data: body);
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }
}

/// Fetches the current user's Firebase ID token and attaches it as a Bearer
/// token on every outgoing request.
class _FirebaseAuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // The token is cached for an hour; past that, getIdToken() has to
        // reach Google, and on a weak network it can stall long enough to
        // block every request (and the cache fallback behind it). Give up
        // after 10 s — an offline request gets served from cache anyway.
        final token =
            await user.getIdToken().timeout(const Duration(seconds: 10));
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        debugPrint('[AuthInterceptor] Token fetch failed: $e');
      }
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

/// Global handler for 4xx and 5xx responses.
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

/// Keeps the last successful body of every GET and replays it so the app shows
/// real data on a weak or missing connection instead of spinners and errors.
///
///  * A GET answered in the last minute is served from memory without a
///    request (see [OfflineCacheService.freshFor]); any write clears that.
///  * A GET with a saved copy on disk gets short timeouts, so a crawling
///    network falls back to the saved copy in seconds rather than after the
///    90 s cold-start allowance. A GET with no saved copy keeps the long
///    timeouts — there is nothing to fall back to, so it may as well wait.
///  * Only connection failures are served from disk. A 4xx/5xx is the server
///    answering, and hiding that behind stale data would turn a real error
///    into a silent one.
class _OfflineCacheInterceptor extends Interceptor {
  static const _cachedConnectTimeout = Duration(seconds: 8);
  static const _cachedReceiveTimeout = Duration(seconds: 12);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uid = _uid;
    if (options.method != 'GET') {
      // A write can change what any GET returns.
      OfflineCacheService.invalidateFresh();
      handler.next(options);
      return;
    }
    if (uid == null) {
      handler.next(options);
      return;
    }

    // Pull-to-refresh calls OfflineCacheService.invalidateFresh() first, so a
    // deliberate refresh always reaches the server.
    final url = options.uri.toString();
    final fresh = OfflineCacheService.fresh(uid, url);
    if (fresh != null) {
      handler.resolve(Response(
        requestOptions: options,
        data: fresh,
        statusCode: 200,
        extra: const {'fromFreshCache': true},
      ));
      return;
    }

    if (await OfflineCacheService.has(uid, url)) {
      options.connectTimeout = _cachedConnectTimeout;
      options.receiveTimeout = _cachedReceiveTimeout;
    }
    handler.next(options);
  }

  bool _isOffline(DioException err) {
    if (err.response != null) return false;
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.unknown;
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final uid = _uid;
    if (uid != null &&
        response.requestOptions.method == 'GET' &&
        response.statusCode == 200 &&
        response.extra['fromFreshCache'] != true) {
      // Fire-and-forget: persisting must never delay the response.
      OfflineCacheService.write(
        uid,
        response.requestOptions.uri.toString(),
        response.data,
      );
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final uid = _uid;
    if (uid == null ||
        err.requestOptions.method != 'GET' ||
        !_isOffline(err)) {
      handler.next(err);
      return;
    }

    final url = err.requestOptions.uri.toString();
    final cached = await OfflineCacheService.read(uid, url);
    if (cached == null) {
      handler.next(err);
      return;
    }

    debugPrint('[API ⤺] offline — serving cached $url');
    handler.resolve(
      Response(
        requestOptions: err.requestOptions,
        data: cached,
        statusCode: 200,
        extra: const {'fromOfflineCache': true},
      ),
    );
  }
}
