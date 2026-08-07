import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';

/// Restores the persisted session at startup, if there is one.
///
/// Deliberately does not validate the tokens against the server: the first
/// authenticated request does that anyway, and the API client refreshes an
/// expired access token transparently.
final class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._sessions);

  final SessionRepository _sessions;

  AuthSession? execute() => _sessions.load();
}
