import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/entities/device_album.dart';
import 'package:photonest/domain/entities/local_photo.dart';

/// [PhotoLibraryGateway] backed by the `photo_manager` plugin.
///
/// Everything platform-specific — permission dialogs, MediaStore queries,
/// change broadcasts — stays behind this class; the rest of the app only
/// sees [LocalPhoto]s and byte buffers.
final class PhotoManagerPhotoLibraryGateway implements PhotoLibraryGateway {
  PhotoManagerPhotoLibraryGateway() {
    _changes = StreamController<void>.broadcast(
      onListen: _startWatching,
      onCancel: _stopWatching,
    );
  }

  late final StreamController<void> _changes;

  @override
  Future<bool> ensureAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    // Limited access (the user picked specific photos) still lets the app
    // read what it was shown, so it counts as granted.
    return state.hasAccess;
  }

  @override
  Future<List<DeviceAlbum>> albums() async {
    final paths = await PhotoManager.getAssetPathList(
      // Photos and videos alike: the upload pipeline handles both, so the
      // chooser must show the albums holding either.
      type: RequestType.common,
      filterOption: _filterOptions(null),
    );
    final albums = <DeviceAlbum>[];
    for (final path in paths) {
      // The platform reports a synthetic album holding everything. Offering
      // it beside the real ones would give the reader two ways to say the
      // same thing; "all albums" is modelled as an empty selection instead.
      if (path.isAll) continue;
      albums.add(
        DeviceAlbum(
          id: path.id,
          name: path.name,
          itemCount: await path.assetCountAsync,
        ),
      );
    }
    return albums;
  }

  @override
  Future<List<LocalPhoto>> photosTakenAfter(
    DateTime? since, {
    int limit = 100,
    int page = 0,
    String? albumId,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: albumId == null,
      type: RequestType.common,
      filterOption: _filterOptions(since),
    );
    // A selected album can disappear between passes (deleted, or on a card
    // that is no longer mounted). Answering empty leaves the rest of the
    // selection working instead of failing the whole pass.
    final matching = albumId == null
        ? paths
        : paths.where((candidate) => candidate.id == albumId).toList();
    if (matching.isEmpty) return const <LocalPhoto>[];
    final path = matching.first;

    final assets = await path.getAssetListPaged(page: page, size: limit);
    return assets.map(_localPhotoOf).toList();
  }

  /// Query shape shared by the album list and the photo pages, so a photo
  /// that shows up in one is the same photo the other counts.
  static FilterOptionGroup _filterOptions(DateTime? since) {
    return FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(needTitle: true),
      createTimeCond: DateTimeCond(
        min: since?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        max: DateTime.now(),
      ),
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
  }

  @override
  Future<Uint8List?> readOriginalBytes(String localId) async {
    final asset = await AssetEntity.fromId(localId);
    return asset?.originBytes;
  }

  @override
  Future<String?> originalFilePath(String localId) async {
    final asset = await AssetEntity.fromId(localId);
    final file = await asset?.originFile;
    return file?.path;
  }

  @override
  Future<Uint8List?> readThumbnail(String localId, {required int size}) async {
    final asset = await AssetEntity.fromId(localId);
    return asset?.thumbnailDataWithSize(ThumbnailSize.square(size));
  }

  @override
  Future<bool> saveToLibrary({
    required String fileName,
    required Uint8List bytes,
    required bool isVideo,
  }) async {
    // Saving writes to the media store, which needs the same grant reading
    // does on the Android versions that ask for one at all.
    if (!await ensureAccess()) return false;
    if (!isVideo) {
      final saved = await PhotoManager.editor.saveImage(
        bytes,
        filename: fileName,
        title: fileName,
      );
      return saved.id.isNotEmpty;
    }
    // `saveVideo` takes a file rather than a buffer, so the bytes go to a
    // temporary file first. It is removed either way — leaving copies of
    // whole videos in the cache directory would quietly fill the device.
    final temporary = File(
      p.join(Directory.systemTemp.path, 'photonest-save-$fileName'),
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      final saved = await PhotoManager.editor.saveVideo(
        temporary,
        title: fileName,
      );
      return saved.id.isNotEmpty;
    } finally {
      if (temporary.existsSync()) await temporary.delete();
    }
  }

  @override
  Stream<void> get libraryChanges => _changes.stream;

  void _startWatching() {
    PhotoManager.addChangeCallback(_onPlatformChange);
    unawaited(PhotoManager.startChangeNotify());
  }

  void _stopWatching() {
    PhotoManager.removeChangeCallback(_onPlatformChange);
    unawaited(PhotoManager.stopChangeNotify());
  }

  /// The platform's payload is intentionally dropped: subscribers re-query
  /// the library, so "something changed" is the whole message.
  void _onPlatformChange(MethodCall call) {
    _changes.add(null);
  }

  static LocalPhoto _localPhotoOf(AssetEntity asset) {
    final title = asset.title;
    final isVideo = asset.type == AssetType.video;
    // MediaStore usually knows the display name; when it does not, a
    // synthetic name keeps the upload content-type resolvable.
    final fallbackName = '${asset.id}.${isVideo ? 'mp4' : 'jpg'}';
    return LocalPhoto(
      localId: asset.id,
      fileName: title == null || title.isEmpty ? fallbackName : title,
      takenAt: asset.createDateTime,
      isVideo: isVideo,
    );
  }
}
