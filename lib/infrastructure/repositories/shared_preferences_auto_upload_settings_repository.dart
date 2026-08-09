import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [AutoUploadSettingsRepository] backed by [SharedPreferences].
final class SharedPreferencesAutoUploadSettingsRepository
    implements AutoUploadSettingsRepository {
  SharedPreferencesAutoUploadSettingsRepository(
    this._preferences, {
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final SharedPreferences _preferences;

  /// Injectable so tests control the "since" stamp.
  final DateTime Function() _clock;

  static const String _enabledKey = 'autoUpload.enabled';
  static const String _sinceKey = 'autoUpload.since';
  static const String _unmeteredOnlyKey = 'autoUpload.unmeteredOnly';
  static const String _backupAlbumIdsKey = 'autoUpload.backupAlbumIds';

  @override
  bool isEnabled() => _preferences.getBool(_enabledKey) ?? false;

  // Absent means "never chosen", and the default for a feature that uploads
  // originals is the one that cannot surprise anyone with a data bill. That
  // also covers installs that predate this setting.
  @override
  bool isUnmeteredOnly() => _preferences.getBool(_unmeteredOnlyKey) ?? true;

  // Absent means "never narrowed", which is the whole library. Stored as a
  // string list so the platform does the escaping — album ids are opaque
  // and may contain anything a separator-joined string would mangle.
  @override
  Set<String> backupAlbumIds() {
    final stored = _preferences.getStringList(_backupAlbumIdsKey);
    if (stored == null) return const <String>{};
    return stored.where((id) => id.isNotEmpty).toSet();
  }

  @override
  DateTime? enabledSince() {
    final raw = _preferences.getString(_sinceKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _preferences.setBool(_enabledKey, enabled);
    // Stamped once, on the first enable ever: photos older than this moment
    // never count as "new", so switching the feature on cannot drag the
    // whole existing camera roll into the upload queue. Kept across
    // off/on cycles so toggling does not re-upload the gap either — the
    // upload history already guards against duplicates.
    if (enabled && _preferences.getString(_sinceKey) == null) {
      await _preferences.setString(_sinceKey, _clock().toIso8601String());
    }
  }

  @override
  Future<void> setUnmeteredOnly(bool unmeteredOnly) async {
    await _preferences.setBool(_unmeteredOnlyKey, unmeteredOnly);
  }

  @override
  Future<void> setBackupAlbumIds(Set<String> albumIds) async {
    // Removed rather than written empty so "never narrowed" and "narrowed
    // back to everything" read the same on the next launch.
    if (albumIds.isEmpty) {
      await _preferences.remove(_backupAlbumIdsKey);
      return;
    }
    await _preferences.setStringList(_backupAlbumIdsKey, albumIds.toList());
  }
}
