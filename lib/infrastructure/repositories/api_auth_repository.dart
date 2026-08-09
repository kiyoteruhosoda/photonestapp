import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/repositories/auth_repository.dart';
import 'package:photonest/domain/value_objects/login_credentials.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [AuthRepository] backed by the PhotoNest `/api/auth` endpoints.
final class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._client);

  final PhotoNestApiClient _client;

  /// The magic `gui:view` scope tells the server to grant the user's full
  /// permission set — an empty scope list would mint a token that can do
  /// nothing. Mirrors what the web frontend sends.
  static const List<String> _requestedScope = ['gui:view'];

  @override
  Future<AuthSession> login(LoginCredentials credentials) async {
    // The endpoint repository already holds `credentials.serverUrl` — the
    // login use case saves it before calling this, and the client resolves
    // its base URL from there.
    final payload = await _client.postJson('/auth/login', {
      'email': credentials.email,
      'password': credentials.password,
      'scope': _requestedScope,
    }, authenticated: false);
    return AuthSession(
      accessToken: payload['access_token'] as String,
      refreshToken: payload['refresh_token'] as String,
      email: credentials.email,
      scopes: _scopesOf(payload['scope']),
    );
  }

  @override
  Future<void> logout(AuthSession session) async {
    await _client.postJson('/auth/logout', const {});
  }

  static List<String> _scopesOf(Object? scope) {
    if (scope is String && scope.isNotEmpty) return scope.split(' ');
    if (scope is List) return scope.map((s) => '$s').toList();
    return const <String>[];
  }
}
