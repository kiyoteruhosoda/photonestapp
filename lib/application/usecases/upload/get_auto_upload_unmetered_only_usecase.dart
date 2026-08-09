import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// Whether automatic upload is restricted to unmetered connections.
final class GetAutoUploadUnmeteredOnlyUseCase {
  const GetAutoUploadUnmeteredOnlyUseCase(this._settings);

  final AutoUploadSettingsRepository _settings;

  bool execute() => _settings.isUnmeteredOnly();
}
