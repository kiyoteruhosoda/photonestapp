import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/media_playback_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';

/// [MediaPlaybackRepository] backed by `POST /api/media/{id}/playback-url`.
///
/// The server answers with a signed, short-lived `/api/dl/…` path; resolving
/// it against the signed-in endpoint is this adapter's whole added value.
/// A 409 (`not_ready`) means the transcode is still running and surfaces
/// unchanged, so the screen can say "try again later" rather than "broken".
final class ApiMediaPlaybackRepository implements MediaPlaybackRepository {
  const ApiMediaPlaybackRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<MediaPlaybackSource> sourceOf(MediaId id) async {
    final payload = await _client.postJson(
      '/media/${id.value}/playback-url',
      const <String, dynamic>{},
    );
    final url = payload['url'];
    if (url is! String || url.isEmpty) {
      throw const InfrastructureError('Playback response carried no URL.');
    }
    final expiresAt = payload['expiresAt'];
    return MediaPlaybackSource(
      url: _client.absoluteUrl(url),
      expiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt)?.toUtc()
          : null,
    );
  }
}
