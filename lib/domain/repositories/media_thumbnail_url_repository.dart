import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// How many thumbnails one issue request may cover.
///
/// The server refuses larger batches. A grid screen holds far fewer than
/// this, so the cap only matters if a caller ever asks for a whole page of
/// several hundred at once.
const int maxThumbnailUrlBatchSize = 500;

/// Boundary to the server's batch issuing of signed thumbnail URLs.
///
/// Distinct from `MediaThumbnailRepository`, which fetches *bytes* through
/// the app server one media item at a time. Signed URLs are served straight
/// from the reverse proxy (or a CDN edge), so a grid can fill from one
/// authenticated round trip instead of one per tile.
abstract interface class MediaThumbnailUrlRepository {
  /// Signed URLs for [ids] at [size], keyed by media id.
  ///
  /// Media the server could not issue for (deleted, purged) is **absent from
  /// the result** rather than reported as a failure: from the grid's side
  /// there is nothing to do about it but render the fallback, and a partial
  /// answer must not fail the whole batch.
  Future<Map<MediaId, SignedMediaUrl>> issue(
    List<MediaId> ids, {
    required int size,
  });
}
