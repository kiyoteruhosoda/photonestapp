import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:photo_manager/photo_manager.dart';

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
  Future<List<LocalPhoto>> photosTakenAfter(
    DateTime? since, {
    int limit = 100,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(needTitle: true),
        createTimeCond: DateTimeCond(
          min: since?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
          max: DateTime.now(),
        ),
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (paths.isEmpty) return const <LocalPhoto>[];

    final assets = await paths.first.getAssetListPaged(page: 0, size: limit);
    return assets.map(_localPhotoOf).toList();
  }

  @override
  Future<Uint8List?> readOriginalBytes(String localId) async {
    final asset = await AssetEntity.fromId(localId);
    return asset?.originBytes;
  }

  @override
  Future<Uint8List?> readThumbnail(String localId, {required int size}) async {
    final asset = await AssetEntity.fromId(localId);
    return asset?.thumbnailDataWithSize(ThumbnailSize.square(size));
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
    return LocalPhoto(
      localId: asset.id,
      // MediaStore usually knows the display name; when it does not, a
      // synthetic JPEG name keeps the upload content-type resolvable.
      fileName: title == null || title.isEmpty ? '${asset.id}.jpg' : title,
      takenAt: asset.createDateTime,
    );
  }
}
