import 'dart:typed_data';

import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/usecases/media/thumbnail_url_batch.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Fetches a server-side thumbnail for a media item, reading and feeding the
/// persistent cache.
///
/// Cache first: a hit costs no network at all, which is what makes the grid
/// render offline and survive app restarts. A cache that cannot be read or
/// written degrades to fetching — a broken cache must never break the
/// screen, so those failures are logged and swallowed here, deliberately.
///
/// A miss goes through a signed URL issued with the rest of the frame's
/// thumbnails ([ThumbnailUrlBatch]), so the bytes come from the reverse proxy
/// or a CDN edge. When no URL could be issued — deleted media, or the batch
/// itself failed — it falls back to the per-media endpoint on the app server.
final class GetMediaThumbnailUseCase {
  const GetMediaThumbnailUseCase(
    this._thumbnails,
    this._cache,
    this._logger,
    this._urlBatch,
  );

  final MediaThumbnailRepository _thumbnails;
  final MediaThumbnailCacheRepository _cache;
  final AppLogger _logger;
  final ThumbnailUrlBatch _urlBatch;

  /// [fetchedAt] stamps the cache entry; tests pass a fixed instant.
  Future<Uint8List> execute(
    MediaId id, {
    int size = 512,
    DateTime? fetchedAt,
  }) async {
    try {
      final cached = await _cache.find(id, size: size);
      if (cached != null) return cached;
    } on AppError catch (error) {
      _logger.warning('[Thumbnail] cache read failed: ${error.message}');
    }

    final bytes = await _fetchBytes(id, size);
    try {
      await _cache.save(
        id,
        size: size,
        bytes: bytes,
        fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
      );
    } on AppError catch (error) {
      _logger.warning('[Thumbnail] cache write failed: ${error.message}');
    }
    return bytes;
  }

  Future<Uint8List> _fetchBytes(MediaId id, int size) async {
    final signed = await _urlBatch.urlFor(id, size: size);
    if (signed == null) return _thumbnails.fetch(id, size: size);
    try {
      return await _thumbnails.fetchFrom(signed);
    } on AppError catch (error) {
      // A signed URL can expire between issuing and use, and an edge can be
      // unreachable while the app server is not. Neither should leave the
      // tile blank when the app server can still answer.
      _logger.warning(
        '[Thumbnail] signed URL fetch failed, falling back: ${error.message}',
      );
      return _thumbnails.fetch(id, size: size);
    }
  }
}
