import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';

/// Observes the persisted session.
///
/// The session store changes outside user actions: the API client rotates
/// the token pair transparently and discards the session when a refresh is
/// rejected. Whoever mirrors the session in memory subscribes here so those
/// background changes surface — most importantly, a dead session flips the
/// app to signed out instead of stranding the user behind failing requests.
final class WatchSessionUseCase {
  const WatchSessionUseCase(this._sessions);

  final SessionRepository _sessions;

  Stream<AuthSession?> execute() => _sessions.changes;
}
