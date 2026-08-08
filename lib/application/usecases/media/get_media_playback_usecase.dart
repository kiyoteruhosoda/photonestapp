import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/domain/repositories/media_playback_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// Obtains a streaming source for a server-side video.
final class GetMediaPlaybackUseCase {
  const GetMediaPlaybackUseCase(this._playback);

  final MediaPlaybackRepository _playback;

  Future<SignedMediaUrl> execute(MediaId id) => _playback.sourceOf(id);
}
