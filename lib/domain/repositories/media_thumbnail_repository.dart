import 'dart:typed_data';

import 'package:photonest/domain/value_objects/media_id.dart';

/// Thumbnail sizes the PhotoNest server can produce.
const Set<int> allowedThumbnailSizes = {256, 512, 1024, 2048};

/// Boundary to the server's thumbnail endpoint.
abstract interface class MediaThumbnailRepository {
  /// Encoded image bytes for media [id] at [size] (one of
  /// [allowedThumbnailSizes]).
  ///
  /// Throws `InfrastructureError` when the thumbnail cannot be fetched —
  /// including when the server is still generating it.
  Future<Uint8List> fetch(MediaId id, {required int size});
}
