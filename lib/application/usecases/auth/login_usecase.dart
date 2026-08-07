import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/auth_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';

/// Signs the user in and persists the resulting session.
final class LoginUseCase {
  const LoginUseCase(this._auth, this._sessions, this._endpoints, this._logger);

  final AuthRepository _auth;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;
  final AppLogger _logger;

  /// Stores the server address first — the API client resolves its base URL
  /// from the endpoint repository, so the login call itself depends on it.
  Future<AuthSession> execute(LoginCredentials credentials) async {
    await _endpoints.save(credentials.serverUrl);
    final session = await _auth.login(credentials);
    await _sessions.save(session);
    _logger.info(
      '[Auth] signed in as ${session.email} '
      '(${session.scopes.length} scopes)',
    );
    return session;
  }
}
