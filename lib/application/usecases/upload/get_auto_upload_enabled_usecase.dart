import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// Whether automatic upload of new photos is switched on.
final class GetAutoUploadEnabledUseCase {
  const GetAutoUploadEnabledUseCase(this._settings);

  final AutoUploadSettingsRepository _settings;

  bool execute() => _settings.isEnabled();
}
