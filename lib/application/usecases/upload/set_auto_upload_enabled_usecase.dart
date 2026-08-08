import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';

/// Switches automatic upload on or off, keeping the platform's background
/// schedule aligned: on registers the periodic sync that runs while the app
/// is closed, off removes it.
final class SetAutoUploadEnabledUseCase {
  const SetAutoUploadEnabledUseCase(
    this._settings,
    this._library,
    this._backgroundSync,
    this._logger,
  );

  final AutoUploadSettingsRepository _settings;
  final PhotoLibraryGateway _library;
  final BackgroundSyncScheduler _backgroundSync;
  final AppLogger _logger;

  /// Returns the effective state: switching on also requests photo-library
  /// access, and stays off when the user denies it.
  Future<bool> execute(bool enabled) async {
    if (enabled && !await _library.ensureAccess()) {
      _logger.warning(
        '[AutoUpload] cannot enable — photo library access denied',
      );
      await _settings.setEnabled(false);
      await _backgroundSync.cancel();
      return false;
    }
    await _settings.setEnabled(enabled);
    if (enabled) {
      await _backgroundSync.ensureScheduled();
    } else {
      await _backgroundSync.cancel();
    }
    _logger.info('[AutoUpload] ${enabled ? 'enabled' : 'disabled'}');
    return enabled;
  }
}
