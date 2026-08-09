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

  @override
  bool isEnabled() => _preferences.getBool(_enabledKey) ?? false;

  // Absent means "never chosen", and the default for a feature that uploads
  // originals is the one that cannot surprise anyone with a data bill. That
  // also covers installs that predate this setting.
  @override
  bool isUnmeteredOnly() => _preferences.getBool(_unmeteredOnlyKey) ?? true;

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
}
