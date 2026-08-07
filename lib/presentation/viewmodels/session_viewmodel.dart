import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:flutterbase/application/usecases/auth/login_usecase.dart';
import 'package:flutterbase/application/usecases/auth/logout_usecase.dart';
import 'package:flutterbase/application/usecases/auth/restore_session_usecase.dart';
import 'package:flutterbase/application/usecases/auth/watch_session_usecase.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';

/// Why the last login attempt failed, as something the UI can translate.
///
/// The domain's error messages are developer-facing English; the login
/// screen maps these kinds onto localised strings instead.
enum LoginFailure {
  /// The submitted form is not even a valid request (bad URL, blank
  /// password, malformed e-mail).
  invalidInput,

  /// The server answered and said no.
  invalidCredentials,

  /// The server could not be reached or errored.
  network,
}

/// Holds the signed-in session for the whole app.
///
/// The router's redirect reads [isAuthenticated] and re-evaluates on every
/// [notifyListeners], which is what turns a login or logout into an
/// automatic navigation. Restores the persisted session synchronously at
/// construction so the very first route resolution already knows the answer.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(
    this._login,
    this._logout,
    RestoreSessionUseCase restoreSession,
    GetApiEndpointUseCase getApiEndpoint,
    WatchSessionUseCase watchSession,
    this._logger,
  ) {
    _session = restoreSession.execute();
    _lastServerUrl = getApiEndpoint.execute();
    // The persisted session can change without any user action — the API
    // client rotates tokens transparently, and discards the session when a
    // refresh is rejected. Mirroring those changes here is what makes the
    // router's guard kick a dead session back to the login screen.
    _storeSubscription = watchSession.execute().listen(_onStoredSessionChange);
    _logger.info(
      '[SessionViewModel] init — '
      '${_session == null ? 'signed out' : 'restored ${_session!.email}'}',
    );
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final AppLogger _logger;

  StreamSubscription<AuthSession?>? _storeSubscription;
  AuthSession? _session;
  Uri? _lastServerUrl;
  bool _busy = false;
  LoginFailure? _lastFailure;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;

  /// True while a login or logout is in flight, so the form can disable
  /// itself instead of double-submitting.
  bool get busy => _busy;

  /// Failure of the most recent login attempt, cleared on the next attempt.
  LoginFailure? get lastFailure => _lastFailure;

  /// Server address to prefill the login form with.
  Uri? get lastServerUrl => _lastServerUrl;

  /// Attempts to sign in. Returns true on success.
  Future<bool> login({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    _busy = true;
    _lastFailure = null;
    notifyListeners();
    try {
      final parsed = Uri.tryParse(serverUrl.trim());
      if (parsed == null) {
        throw const DomainError('Server URL is not a valid URL.');
      }
      final credentials = LoginCredentials(
        serverUrl: parsed,
        email: email,
        password: password,
      );
      _session = await _login.execute(credentials);
      _lastServerUrl = credentials.serverUrl;
      return true;
    } on DomainError {
      _lastFailure = LoginFailure.invalidInput;
      return false;
    } on AuthenticationError catch (error) {
      _logger.warning('[SessionViewModel] login rejected: ${error.message}');
      _lastFailure = LoginFailure.invalidCredentials;
      return false;
    } on InfrastructureError catch (error) {
      _logger.warning('[SessionViewModel] login failed: ${error.message}');
      _lastFailure = LoginFailure.network;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Signs out. Always succeeds locally — see `LogoutUseCase`.
  Future<void> logout() async {
    _busy = true;
    notifyListeners();
    try {
      await _logout.execute();
      _session = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Mirrors a store-driven session change (token rotation, forced expiry).
  void _onStoredSessionChange(AuthSession? stored) {
    if (stored == _session) return;
    if (stored == null && _session != null) {
      _logger.info('[SessionViewModel] stored session expired — signing out');
    }
    _session = stored;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_storeSubscription?.cancel());
    super.dispose();
  }
}
