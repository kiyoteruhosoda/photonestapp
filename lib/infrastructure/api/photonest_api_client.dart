import 'dart:convert';
import 'dart:typed_data';

import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:http/http.dart' as http;

/// HTTP access to the PhotoNest server's `/api` endpoints.
///
/// Owns the two concerns every API repository would otherwise duplicate:
/// resolving the base URL the user signed in to, and authentication —
/// attaching the bearer token, and on a 401 exchanging the refresh token for
/// a new pair (persisting it, because refresh tokens rotate server-side)
/// before retrying the request once.
final class PhotoNestApiClient {
  PhotoNestApiClient({
    required http.Client httpClient,
    required SessionRepository sessionStore,
    required ApiEndpointRepository endpointStore,
    required AppLogger appLogger,
  }) : _http = httpClient,
       _sessions = sessionStore,
       _endpoints = endpointStore,
       _logger = appLogger;

  final http.Client _http;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;
  final AppLogger _logger;

  /// The refresh currently in flight, when there is one.
  ///
  /// Refresh tokens rotate and the server honours only the newest one, so
  /// two concurrent refreshes — an album grid's worth of thumbnail requests
  /// all hitting 401 together — would race: one wins, every other one fails
  /// with a token the server just forgot. All callers therefore share a
  /// single in-flight refresh.
  Future<void>? _refreshInFlight;

  /// POSTs [body] as JSON to [path] and decodes the JSON response.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    final response = await _sendWithRetry(
      authenticated: authenticated,
      build: () => http.Request('POST', _resolve(path))
        ..headers['Content-Type'] = 'application/json'
        ..headers.addAll(headers ?? const {})
        ..body = jsonEncode(body),
    );
    return _decodeJson(response);
  }

  /// GETs [path] and decodes the JSON response.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _sendWithRetry(
      authenticated: true,
      build: () => http.Request('GET', _resolve(path, query)),
    );
    return _decodeJson(response);
  }

  /// GETs [path] and returns the raw body — thumbnails and other binaries.
  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final response = await _sendWithRetry(
      authenticated: true,
      build: () => http.Request('GET', _resolve(path, query)),
    );
    return response.bodyBytes;
  }

  /// POSTs one file as `multipart/form-data` and decodes the JSON response.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required http.MultipartFile Function() buildFile,
    Map<String, String>? headers,
  }) async {
    final response = await _sendWithRetry(
      authenticated: true,
      build: () => http.MultipartRequest('POST', _resolve(path))
        ..headers.addAll(headers ?? const {})
        ..files.add(buildFile()),
    );
    return _decodeJson(response);
  }

  /// Builds the absolute URL for an API [path] like `/albums`.
  ///
  /// Throws [InfrastructureError] when no server address is stored — that
  /// means a programming error: authenticated calls only happen after login,
  /// and login saves the endpoint first.
  Uri _resolve(String path, [Map<String, String>? query]) {
    final base = _endpoints.load();
    if (base == null) {
      throw const InfrastructureError('No PhotoNest server is configured.');
    }
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$basePath/api$path', queryParameters: query);
  }

  /// The absolute form of a server-relative path the API returned, such as
  /// the signed `/api/dl/…` playback URLs.
  ///
  /// Unlike [_resolve] this adds no `/api` prefix — the server already spelt
  /// the full path. Signed URLs embed their own authorisation, so callers
  /// can hand the result to a player or browser without the bearer token.
  Uri absoluteUrl(String serverPath) {
    final base = _endpoints.load();
    if (base == null) {
      throw const InfrastructureError('No PhotoNest server is configured.');
    }
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final relative = serverPath.startsWith('/') ? serverPath : '/$serverPath';
    return base.replace(path: '$basePath$relative');
  }

  /// Sends the request [build] produces; on a 401 refreshes the session and
  /// sends a freshly built copy once more.
  ///
  /// [build] is a factory because an [http.Request] cannot be sent twice.
  Future<http.Response> _sendWithRetry({
    required bool authenticated,
    required http.BaseRequest Function() build,
  }) async {
    final usedToken = authenticated ? _sessions.load()?.accessToken : null;
    var response = await _send(build(), authenticated: authenticated);
    if (authenticated && response.statusCode == 401) {
      _logger.debug('[Api] access token rejected — refreshing session');
      await _refreshSessionUnlessReplaced(usedToken);
      response = await _send(build(), authenticated: true);
    }
    if (response.statusCode >= 400) {
      throw _errorFor(response);
    }
    return response;
  }

  /// Refreshes the session, unless another request already did.
  ///
  /// [rejectedToken] is the access token the failing request carried. When
  /// the stored token differs by the time we get here, a concurrent request
  /// has already refreshed — retrying with the stored token is enough.
  /// Otherwise all concurrent callers await the same in-flight refresh.
  Future<void> _refreshSessionUnlessReplaced(String? rejectedToken) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    if (_sessions.load()?.accessToken != rejectedToken) {
      return Future<void>.value();
    }
    final refresh = _refreshSession().whenComplete(
      () => _refreshInFlight = null,
    );
    _refreshInFlight = refresh;
    return refresh;
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    required bool authenticated,
  }) async {
    if (authenticated) {
      final session = _sessions.load();
      if (session == null) {
        throw const AuthenticationError('Not signed in.');
      }
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    try {
      return await http.Response.fromStream(await _http.send(request));
    } on http.ClientException catch (error) {
      throw NetworkUnreachableError(
        'Could not reach the server: ${error.message}',
        cause: error,
      );
    }
  }

  /// Exchanges the stored refresh token for a new token pair and persists
  /// it. Refresh tokens rotate: the server forgets the one just used, so
  /// failing to persist here would strand the user at the next refresh.
  Future<void> _refreshSession() async {
    final session = _sessions.load();
    if (session == null) {
      throw const AuthenticationError('Not signed in.');
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(
          http.Request('POST', _resolve('/auth/refresh'))
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode({'refresh_token': session.refreshToken}),
        ),
      );
    } on http.ClientException catch (error) {
      throw NetworkUnreachableError(
        'Could not reach the server: ${error.message}',
        cause: error,
      );
    }
    if (response.statusCode >= 400) {
      _logger.warning('[Api] session refresh rejected — signing out');
      // The refresh token is dead, so the stored session can never work
      // again. Clearing it flips the app to signed out (the session store
      // broadcasts the change) instead of stranding the user behind an
      // authenticated-looking UI whose every request fails.
      await _sessions.clear();
      throw const AuthenticationError(
        'The session has expired. Please sign in again.',
        code: 'invalid_token',
      );
    }
    final payload = _decodeJson(response);
    final refreshed = session.withTokens(
      accessToken: payload['access_token'] as String,
      refreshToken: payload['refresh_token'] as String,
      scopes: _splitScope(payload['scope']),
    );
    await _sessions.save(refreshed);
    _logger.debug('[Api] session refreshed');
  }

  static Map<String, dynamic> _decodeJson(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const InfrastructureError('Unexpected response shape from server.');
    }
    return decoded;
  }

  /// The server sends scope as a space-separated string; older builds may
  /// send a list. Both collapse to a plain list of codes.
  static List<String> _splitScope(Object? scope) {
    if (scope is List) return scope.map((s) => '$s').toList();
    if (scope is String && scope.isNotEmpty) return scope.split(' ');
    return const <String>[];
  }

  /// Maps an HTTP error to a typed [AppError], surfacing the server's
  /// `{"detail": {"error", "message"}}` payload when present.
  static AppError _errorFor(http.Response response) {
    String? code;
    var message = 'Server error (HTTP ${response.statusCode}).';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        final source = detail is Map<String, dynamic> ? detail : body;
        code = source['error'] as String?;
        message = (source['message'] as String?) ?? message;
      }
    } on FormatException {
      // A non-JSON error body (a proxy page, for instance) keeps the
      // generic message.
    }
    if (response.statusCode == 401) {
      return AuthenticationError(message, code: code);
    }
    return InfrastructureError(message, code: code);
  }
}
