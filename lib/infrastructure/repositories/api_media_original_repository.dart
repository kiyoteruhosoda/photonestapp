import 'dart:typed_data';

import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/media_original_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';

/// [MediaOriginalRepository] backed by `POST /api/media/{id}/original-url`.
///
/// The server answers with a signed, short-lived `/api/dl/…` path, the same
/// shape the playback endpoint uses; resolving it against the signed-in
/// endpoint is this adapter's whole added value.
final class ApiMediaOriginalRepository implements MediaOriginalRepository {
  const ApiMediaOriginalRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<SignedMediaUrl> originalOf(MediaId id) async {
    final payload = await _client.postJson(
      '/media/${id.value}/original-url',
      const <String, dynamic>{},
    );
    final url = payload['url'];
    if (url is! String || url.isEmpty) {
      throw const InfrastructureError('Original response carried no URL.');
    }
    final expiresAt = payload['expiresAt'];
    return SignedMediaUrl(
      url: _client.absoluteUrl(url),
      expiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt)?.toUtc()
          : null,
    );
  }

  @override
  Future<Uint8List> downloadOriginal(MediaId id) async {
    // Fetched through the signed URL rather than an API path: the token
    // carries its own authorisation, and it is the only handle the server
    // offers on the original file.
    final source = await originalOf(id);
    return _client.getBytesFrom(source.url);
  }
}
