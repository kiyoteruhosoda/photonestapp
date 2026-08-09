import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_thumbnail_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_url_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaThumbnailUrlRepository] backed by `POST /api/media/thumb-urls`.
///
/// The response separates `items` (issued) from `failed` (deleted or purged
/// media). Only the issued ones are returned; see the interface for why a
/// partial answer is the contract rather than an error.
final class ApiMediaThumbnailUrlRepository
    implements MediaThumbnailUrlRepository {
  const ApiMediaThumbnailUrlRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<Map<MediaId, SignedMediaUrl>> issue(
    List<MediaId> ids, {
    required int size,
  }) async {
    if (!allowedThumbnailSizes.contains(size)) {
      throw InfrastructureError(
        'Thumbnail size $size is not one of $allowedThumbnailSizes.',
      );
    }
    if (ids.isEmpty) return const <MediaId, SignedMediaUrl>{};
    if (ids.length > maxThumbnailUrlBatchSize) {
      throw InfrastructureError(
        'Cannot issue more than $maxThumbnailUrlBatchSize thumbnail URLs '
        'at once (asked for ${ids.length}).',
      );
    }

    final payload = await _client.postJson('/media/thumb-urls', {
      'ids': ids.map((id) => id.value).toList(growable: false),
      'size': size,
    });
    final items = payload['items'];
    if (items is! List) {
      throw const InfrastructureError('Thumbnail URL response had no items.');
    }

    final issued = <MediaId, SignedMediaUrl>{};
    for (final raw in items.whereType<Map<String, dynamic>>()) {
      final mediaId = raw['mediaId'];
      final url = raw['url'];
      // A malformed entry is skipped rather than failing the batch: the
      // grid renders that one tile's fallback and the rest still fill.
      if (mediaId is! int || url is! String || url.isEmpty) continue;
      final expiresAt = raw['expiresAt'];
      issued[MediaId(mediaId)] = SignedMediaUrl(
        url: _client.absoluteUrl(url),
        expiresAt: expiresAt is String
            ? DateTime.tryParse(expiresAt)?.toUtc()
            : null,
      );
    }
    return issued;
  }
}
