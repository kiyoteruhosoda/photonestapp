import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/entities/device_album.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

/// What the backup-target chooser renders: either "no access" or the
/// device's albums together with the ones currently selected.
final class DeviceAlbumChoices {
  const DeviceAlbumChoices({
    required this.accessGranted,
    required this.albums,
    required this.selectedIds,
  });

  const DeviceAlbumChoices.denied()
    : accessGranted = false,
      albums = const <DeviceAlbum>[],
      selectedIds = const <String>{};

  /// False when the user has not granted photo-library access — the chooser
  /// explains that instead of showing an empty list.
  final bool accessGranted;

  final List<DeviceAlbum> albums;

  /// Album ids automatic upload is limited to; empty means the whole
  /// library. May name albums missing from [albums] — a selected album that
  /// has since been deleted keeps its place until the user changes the
  /// choice.
  final Set<String> selectedIds;
}

/// Lists the device's albums for the backup-target chooser.
final class ListDeviceAlbumsUseCase {
  const ListDeviceAlbumsUseCase(this._library, this._settings);

  final PhotoLibraryGateway _library;
  final AutoUploadSettingsRepository _settings;

  Future<DeviceAlbumChoices> execute() async {
    // Asked here rather than assumed from the upload grid: the chooser can
    // be opened on a launch where nothing else has touched the library yet.
    if (!await _library.ensureAccess()) {
      return const DeviceAlbumChoices.denied();
    }
    final albums = await _library.albums();
    // Biggest first: the camera roll is what most people are looking for,
    // and it is almost always the largest album on the device.
    final sorted = [...albums]
      ..sort((a, b) => b.itemCount.compareTo(a.itemCount));
    return DeviceAlbumChoices(
      accessGranted: true,
      albums: sorted,
      selectedIds: _settings.backupAlbumIds(),
    );
  }
}
