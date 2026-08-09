import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// Which device albums automatic upload is limited to.
///
/// Empty means the whole library. Reads only what is persisted, so the
/// upload screen can show the current target without asking the platform
/// for library access.
final class GetBackupAlbumsUseCase {
  const GetBackupAlbumsUseCase(this._settings);

  final AutoUploadSettingsRepository _settings;

  Set<String> execute() => _settings.backupAlbumIds();
}
