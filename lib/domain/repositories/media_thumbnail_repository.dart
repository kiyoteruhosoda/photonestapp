import 'dart:typed_data';

import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Thumbnail sizes the PhotoNest server can produce.
const Set<int> allowedThumbnailSizes = {256, 512, 1024, 2048};

/// Boundary to the server's thumbnail bytes.
abstract interface class MediaThumbnailRepository {
  /// Encoded image bytes for media [id] at [size] (one of
  /// [allowedThumbnailSizes]), read through the app server.
  ///
  /// Every call is an authenticated round trip to the app server, so this is
  /// the fallback for when no signed URL could be issued. Prefer [fetchFrom].
  ///
  /// Throws `InfrastructureError` when the thumbnail cannot be fetched —
  /// including when the server is still generating it.
  Future<Uint8List> fetch(MediaId id, {required int size});

  /// Encoded image bytes from a signed URL the server issued.
  ///
  /// The signature is the authorisation, so this is served by the reverse
  /// proxy (or a CDN edge) without reaching the app server.
  Future<Uint8List> fetchFrom(SignedMediaUrl url);
}
