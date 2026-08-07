import 'dart:typed_data';

import 'package:flutterbase/domain/repositories/media_thumbnail_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// Fetches a server-side thumbnail for a media item.
final class GetMediaThumbnailUseCase {
  const GetMediaThumbnailUseCase(this._thumbnails);

  final MediaThumbnailRepository _thumbnails;

  Future<Uint8List> execute(MediaId id, {int size = 512}) =>
      _thumbnails.fetch(id, size: size);
}
