import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/auth_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';

/// Signs the user out locally, revoking the session server-side when it can.
final class LogoutUseCase {
  const LogoutUseCase(this._auth, this._sessions, this._logger);

  final AuthRepository _auth;
  final SessionRepository _sessions;
  final AppLogger _logger;

  /// The local session is always cleared. Server-side revocation is
  /// best-effort by design: an unreachable server must not trap the user in
  /// a signed-in state, so an [AppError] from the revoke call is logged and
  /// deliberately not rethrown.
  Future<void> execute() async {
    final session = _sessions.load();
    if (session == null) return;
    try {
      await _auth.logout(session);
    } on AppError catch (error) {
      _logger.warning(
        '[Auth] server-side logout failed — clearing local session anyway: '
        '${error.message}',
      );
    }
    await _sessions.clear();
    _logger.info('[Auth] signed out ${session.email}');
  }
}
