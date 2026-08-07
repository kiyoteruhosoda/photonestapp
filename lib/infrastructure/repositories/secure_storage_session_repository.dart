import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SessionRepository] backed by the platform keystore
/// (`flutter_secure_storage` — Android Keystore under the hood).
///
/// The secure storage API is asynchronous, but [SessionRepository.load] is
/// synchronous by contract: [create] reads the stored session once at
/// startup and every later read is served from the in-memory copy, which
/// [save] and [clear] keep in step with the keystore.
final class SecureStorageSessionRepository implements SessionRepository {
  SecureStorageSessionRepository._(this._storage, this._cached);

  final FlutterSecureStorage _storage;
  AuthSession? _cached;

  /// Never closed by design: one repository instance lives as long as the
  /// process, and the observers do too.
  // ignore: close_sinks
  final StreamController<AuthSession?> _changes =
      StreamController<AuthSession?>.broadcast();

  static const String _accessTokenKey = 'auth.accessToken';
  static const String _refreshTokenKey = 'auth.refreshToken';
  static const String _emailKey = 'auth.email';
  static const String _scopesKey = 'auth.scopes';

  /// Opens the keystore-backed store, migrating any tokens an earlier app
  /// version left in [legacyPreferences] (SharedPreferences, plaintext).
  ///
  /// The legacy keys are removed in either case: once a keystore exists,
  /// plaintext copies of the tokens must not linger on disk.
  static Future<SecureStorageSessionRepository> create(
    FlutterSecureStorage storage,
    SharedPreferences legacyPreferences,
  ) async {
    await _migrateLegacyTokens(storage, legacyPreferences);
    return SecureStorageSessionRepository._(
      storage,
      await _readStoredSession(storage),
    );
  }

  @override
  AuthSession? load() => _cached;

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(key: _emailKey, value: session.email);
    // Scope codes never contain spaces (they are `area:action` identifiers),
    // so the server's own space-separated wire format round-trips safely.
    await _storage.write(key: _scopesKey, value: session.scopes.join(' '));
    _cached = session;
    _changes.add(session);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _scopesKey);
    _cached = null;
    _changes.add(null);
  }

  @override
  Stream<AuthSession?> get changes => _changes.stream;

  static Future<AuthSession?> _readStoredSession(
    FlutterSecureStorage storage,
  ) async {
    final accessToken = await storage.read(key: _accessTokenKey);
    final refreshToken = await storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    final scopes = await storage.read(key: _scopesKey);
    try {
      return AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        email: await storage.read(key: _emailKey) ?? '',
        scopes: scopes == null || scopes.isEmpty
            ? const <String>[]
            : scopes.split(' '),
      );
    } on DomainError {
      // A blank token can only mean corrupted storage; surfacing it as
      // "signed out" beats crashing at startup.
      return null;
    }
  }

  /// Moves tokens saved by the SharedPreferences-era implementation into
  /// the keystore, then deletes the plaintext copies.
  static Future<void> _migrateLegacyTokens(
    FlutterSecureStorage storage,
    SharedPreferences legacyPreferences,
  ) async {
    final legacyAccess = legacyPreferences.getString(_accessTokenKey);
    final legacyRefresh = legacyPreferences.getString(_refreshTokenKey);
    final hasLegacy = legacyAccess != null && legacyRefresh != null;

    final alreadyMigrated = await storage.read(key: _accessTokenKey) != null;
    if (hasLegacy && !alreadyMigrated) {
      await storage.write(key: _accessTokenKey, value: legacyAccess);
      await storage.write(key: _refreshTokenKey, value: legacyRefresh);
      await storage.write(
        key: _emailKey,
        value: legacyPreferences.getString(_emailKey) ?? '',
      );
      await storage.write(
        key: _scopesKey,
        value: (legacyPreferences.getStringList(_scopesKey) ?? const []).join(
          ' ',
        ),
      );
    }

    await legacyPreferences.remove(_accessTokenKey);
    await legacyPreferences.remove(_refreshTokenKey);
    await legacyPreferences.remove(_emailKey);
    await legacyPreferences.remove(_scopesKey);
  }
}
