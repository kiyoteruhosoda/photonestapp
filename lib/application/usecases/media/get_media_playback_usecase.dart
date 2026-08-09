import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/repositories/media_playback_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Obtains a streaming source for a server-side video.
final class GetMediaPlaybackUseCase {
  const GetMediaPlaybackUseCase(this._playback);

  final MediaPlaybackRepository _playback;

  Future<SignedMediaUrl> execute(MediaId id) => _playback.sourceOf(id);
}
