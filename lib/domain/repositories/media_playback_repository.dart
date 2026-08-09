import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Boundary to the server's video playback endpoint.
abstract interface class MediaPlaybackRepository {
  /// A streaming source for video [id].
  ///
  /// Throws `InfrastructureError` with code `not_ready` while the server is
  /// still transcoding the video, and with code `not_found` when the media
  /// does not exist or has no playback rendition.
  Future<SignedMediaUrl> sourceOf(MediaId id);
}
