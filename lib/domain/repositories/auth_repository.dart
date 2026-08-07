import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';

/// Boundary to the server's authentication endpoints.
///
/// Implementations live in Infrastructure. Session *persistence* is a
/// separate concern — see `SessionRepository`.
abstract interface class AuthRepository {
  /// Opens a session for [credentials].
  ///
  /// Throws `AuthenticationError` when the server rejects the credentials
  /// and `InfrastructureError` when it cannot be reached.
  Future<AuthSession> login(LoginCredentials credentials);

  /// Exchanges [session]'s refresh token for a fresh token pair.
  ///
  /// The returned session must be persisted immediately: refresh tokens
  /// rotate, and the server forgets the one that was just used.
  Future<AuthSession> refresh(AuthSession session);

  /// Revokes [session] on the server.
  Future<void> logout(AuthSession session);
}
