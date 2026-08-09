import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/background_sync_scheduler.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// Restricts automatic upload to unmetered connections, or lifts the
/// restriction.
///
/// The platform's background schedule carries the same restriction as a
/// registration constraint, so changing the setting has to re-register it —
/// otherwise the app would honour the new choice while the OS kept waking it
/// under the old one.
final class SetAutoUploadUnmeteredOnlyUseCase {
  const SetAutoUploadUnmeteredOnlyUseCase(
    this._settings,
    this._backgroundSync,
    this._logger,
  );

  final AutoUploadSettingsRepository _settings;
  final BackgroundSyncScheduler _backgroundSync;
  final AppLogger _logger;

  Future<void> execute(bool unmeteredOnly) async {
    await _settings.setUnmeteredOnly(unmeteredOnly);
    // Nothing to re-register while auto-upload is off: switching it back on
    // registers the schedule with whatever this setting says at that point.
    if (_settings.isEnabled()) {
      await _backgroundSync.ensureScheduled(unmeteredOnly: unmeteredOnly);
    }
    _logger.info(
      '[AutoUpload] unmetered-only ${unmeteredOnly ? 'enabled' : 'disabled'}',
    );
  }
}
