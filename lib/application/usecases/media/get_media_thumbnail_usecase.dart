import 'dart:typed_data';

import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// Fetches a server-side thumbnail for a media item, reading and feeding the
/// persistent cache.
///
/// Cache first: a hit costs no network at all, which is what makes the grid
/// render offline and survive app restarts. A cache that cannot be read or
/// written degrades to fetching — a broken cache must never break the
/// screen, so those failures are logged and swallowed here, deliberately.
final class GetMediaThumbnailUseCase {
  const GetMediaThumbnailUseCase(this._thumbnails, this._cache, this._logger);

  final MediaThumbnailRepository _thumbnails;
  final MediaThumbnailCacheRepository _cache;
  final AppLogger _logger;

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

    final bytes = await _thumbnails.fetch(id, size: size);
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
}
