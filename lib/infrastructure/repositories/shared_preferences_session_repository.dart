import 'dart:async';

import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SessionRepository] backed by [SharedPreferences].
///
/// Development-stage storage: SharedPreferences is not encrypted at rest.
/// Moving the tokens to the platform keystore is a pre-production hardening
/// task — tracked in `docs/Progress.md`.
final class SharedPreferencesSessionRepository implements SessionRepository {
  SharedPreferencesSessionRepository(this._preferences);

  final SharedPreferences _preferences;

  /// Never closed by design: one repository instance lives as long as the
  /// process, and the observers do too.
  // ignore: close_sinks
  final StreamController<AuthSession?> _changes =
      StreamController<AuthSession?>.broadcast();

  static const String _accessTokenKey = 'auth.accessToken';
  static const String _refreshTokenKey = 'auth.refreshToken';
  static const String _emailKey = 'auth.email';
  static const String _scopesKey = 'auth.scopes';

  @override
  AuthSession? load() {
    final accessToken = _preferences.getString(_accessTokenKey);
    final refreshToken = _preferences.getString(_refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    try {
      return AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        email: _preferences.getString(_emailKey) ?? '',
        scopes: _preferences.getStringList(_scopesKey) ?? const <String>[],
      );
    } on DomainError {
      // A blank token can only mean corrupted storage; surfacing it as
      // "signed out" beats crashing at startup.
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    await _preferences.setString(_accessTokenKey, session.accessToken);
    await _preferences.setString(_refreshTokenKey, session.refreshToken);
    await _preferences.setString(_emailKey, session.email);
    await _preferences.setStringList(_scopesKey, session.scopes);
    _changes.add(session);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_emailKey);
    await _preferences.remove(_scopesKey);
    _changes.add(null);
  }

  @override
  Stream<AuthSession?> get changes => _changes.stream;
}
