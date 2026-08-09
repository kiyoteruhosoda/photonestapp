import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// Limits automatic upload to a set of device albums, or lifts the limit.
///
/// Unlike the unmetered-only setting, the platform's background schedule
/// carries no constraint for this: which albums a pass reads is decided
/// inside the pass, so nothing has to be re-registered.
final class SetBackupAlbumsUseCase {
  const SetBackupAlbumsUseCase(this._settings, this._logger);

  final AutoUploadSettingsRepository _settings;
  final AppLogger _logger;

  Future<void> execute(Set<String> albumIds) async {
    await _settings.setBackupAlbumIds(albumIds);
    // Album ids and names are not logged: the names are the reader's own
    // words for their photos.
    _logger.info(
      albumIds.isEmpty
          ? '[AutoUpload] backup target set to the whole library'
          : '[AutoUpload] backup target set to ${albumIds.length} album(s)',
    );
  }
}
