import 'dart:typed_data';

import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// Boundary to the server's untouched originals.
///
/// Distinct from the thumbnail repository: those are renditions the server
/// generated for display, this is the file the camera produced. Only the
/// viewer's "show the original" and "save to this device" actions reach for
/// it, because an original can be orders of magnitude larger than the
/// 2048px rendition the grid and the viewer open with.
abstract interface class MediaOriginalRepository {
  /// A signed URL the original can be fetched from.
  ///
  /// Throws `InfrastructureError` with code `not_found` when the media does
  /// not exist, and `gone` when it is in the server's trash.
  Future<SignedMediaUrl> originalOf(MediaId id);

  /// The original's bytes.
  ///
  /// Materialises the whole file in memory, so this is for the explicit
  /// "save to my device" action only — never for rendering.
  Future<Uint8List> downloadOriginal(MediaId id);
}
