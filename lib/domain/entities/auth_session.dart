import 'package:flutterbase/domain/errors/app_error.dart';

/// A signed-in session with the PhotoNest server.
///
/// Carries the token pair the API client needs and the identity/permission
/// facts the UI wants to show. The refresh token rotates on every refresh —
/// the server keeps only the newest one — so whoever refreshes must persist
/// the replacement session immediately.
final class AuthSession {
  /// Throws [DomainError] when either token is blank: a session without both
  /// tokens cannot authenticate anything and must not be stored.
  factory AuthSession({
    required String accessToken,
    required String refreshToken,
    required String email,
    List<String> scopes = const <String>[],
  }) {
    if (accessToken.trim().isEmpty) {
      throw const DomainError('Access token must not be blank.');
    }
    if (refreshToken.trim().isEmpty) {
      throw const DomainError('Refresh token must not be blank.');
    }
    return AuthSession._(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      scopes: List.unmodifiable(scopes),
    );
  }

  const AuthSession._({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
    required this.scopes,
  });

  /// Bearer token attached to every API request. Short-lived.
  final String accessToken;

  /// Long-lived token exchanged for a new pair when the access token
  /// expires. Rotates on every use.
  final String refreshToken;

  /// E-mail the session was opened with, for display only.
  final String email;

  /// Permission codes the server granted this session, e.g. `album:view`.
  final List<String> scopes;

  /// Whether the server granted [scope] to this session.
  bool hasScope(String scope) => scopes.contains(scope);

  /// The same identity with a fresh token pair, after a refresh.
  AuthSession withTokens({
    required String accessToken,
    required String refreshToken,
    List<String>? scopes,
  }) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      scopes: scopes ?? this.scopes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthSession &&
          other.accessToken == accessToken &&
          other.refreshToken == refreshToken &&
          other.email == email);

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, email);

  /// Deliberately token-free: a session in a log line is an incident.
  @override
  String toString() => 'AuthSession($email, scopes: ${scopes.length})';
}
