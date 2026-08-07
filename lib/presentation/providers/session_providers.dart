import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:flutterbase/application/usecases/auth/login_usecase.dart';
import 'package:flutterbase/application/usecases/auth/logout_usecase.dart';
import 'package:flutterbase/application/usecases/auth/restore_session_usecase.dart';
import 'package:flutterbase/application/usecases/auth/watch_session_usecase.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────

final Provider<LoginUseCase> loginUseCaseProvider = Provider<LoginUseCase>((
  ref,
) {
  throw UnimplementedError(missingOverrideMessage('loginUseCaseProvider'));
});

final Provider<LogoutUseCase> logoutUseCaseProvider = Provider<LogoutUseCase>((
  ref,
) {
  throw UnimplementedError(missingOverrideMessage('logoutUseCaseProvider'));
});

final Provider<RestoreSessionUseCase> restoreSessionUseCaseProvider =
    Provider<RestoreSessionUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('restoreSessionUseCaseProvider'),
      );
    });

final Provider<GetApiEndpointUseCase> getApiEndpointUseCaseProvider =
    Provider<GetApiEndpointUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getApiEndpointUseCaseProvider'),
      );
    });

final Provider<WatchSessionUseCase> watchSessionUseCaseProvider =
    Provider<WatchSessionUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('watchSessionUseCaseProvider'),
      );
    });

// ─── State ─────────────────────────────────────────────────────────────────

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

/// The signed-in session and the login form's transient state.
final class SessionState {
  const SessionState({
    this.session,
    this.lastServerUrl,
    this.busy = false,
    this.lastFailure,
  });

  final AuthSession? session;

  /// Server address to prefill the login form with.
  final Uri? lastServerUrl;

  /// True while a login or logout is in flight, so the form can disable
  /// itself instead of double-submitting.
  final bool busy;

  /// Failure of the most recent login attempt, cleared on the next attempt.
  final LoginFailure? lastFailure;

  bool get isAuthenticated => session != null;
}

/// Holds the signed-in session for the whole app.
///
/// The router's guard reads [SessionState.isAuthenticated] and re-evaluates
/// on every state change (via the refresh bridge the composition root
/// installs), which is what turns a login or logout into automatic
/// navigation. Restores the persisted session synchronously at first read,
/// and mirrors store-driven changes — the API client rotates tokens
/// transparently and discards the session when a refresh is rejected.
final NotifierProvider<SessionNotifier, SessionState> sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Manages login, logout, and the mirror of the persisted session.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    final restored = ref.read(restoreSessionUseCaseProvider).execute();
    final subscription = ref
        .read(watchSessionUseCaseProvider)
        .execute()
        .listen(_onStoredSessionChange);
    ref.onDispose(subscription.cancel);
    ref
        .read(appLoggerProvider)
        .info(
          '[Session] init — '
          '${restored == null ? 'signed out' : 'restored ${restored.email}'}',
        );
    return SessionState(
      session: restored,
      lastServerUrl: ref.read(getApiEndpointUseCaseProvider).execute(),
    );
  }

  /// Attempts to sign in. Returns true on success.
  Future<bool> login({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    final logger = ref.read(appLoggerProvider);
    state = SessionState(
      session: state.session,
      lastServerUrl: state.lastServerUrl,
      busy: true,
    );
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
      final session = await ref.read(loginUseCaseProvider).execute(credentials);
      state = SessionState(
        session: session,
        lastServerUrl: credentials.serverUrl,
      );
      return true;
    } on DomainError {
      _failWith(LoginFailure.invalidInput);
      return false;
    } on AuthenticationError catch (error) {
      logger.warning('[Session] login rejected: ${error.message}');
      _failWith(LoginFailure.invalidCredentials);
      return false;
    } on InfrastructureError catch (error) {
      logger.warning('[Session] login failed: ${error.message}');
      _failWith(LoginFailure.network);
      return false;
    }
  }

  /// Signs out. Always succeeds locally — see `LogoutUseCase`.
  Future<void> logout() async {
    state = SessionState(
      session: state.session,
      lastServerUrl: state.lastServerUrl,
      busy: true,
    );
    await ref.read(logoutUseCaseProvider).execute();
    state = SessionState(lastServerUrl: state.lastServerUrl);
  }

  void _failWith(LoginFailure failure) {
    state = SessionState(
      lastServerUrl: state.lastServerUrl,
      lastFailure: failure,
    );
  }

  /// Mirrors a store-driven session change (token rotation, forced expiry).
  void _onStoredSessionChange(AuthSession? stored) {
    if (stored == state.session) return;
    if (stored == null && state.session != null) {
      ref
          .read(appLoggerProvider)
          .info('[Session] stored session expired — signing out');
    }
    state = SessionState(session: stored, lastServerUrl: state.lastServerUrl);
  }
}

/// Whose data the server-backed caches belong to.
///
/// Server-backed providers `ref.watch` this in their `build`, so signing
/// out — or into another account or server — rebuilds them with fresh data.
/// A transparent token rotation keeps the same identity and therefore does
/// not blow the caches.
final Provider<({String? email, Uri? serverUrl})> sessionIdentityProvider =
    Provider<({String? email, Uri? serverUrl})>((ref) {
      final state = ref.watch(sessionProvider);
      return (email: state.session?.email, serverUrl: state.lastServerUrl);
    });
