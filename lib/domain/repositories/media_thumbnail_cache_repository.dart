import 'dart:typed_data';

import 'package:flutterbase/domain/value_objects/media_id.dart';

/// Local, persistent store of server thumbnails already downloaded.
///
/// This is what survives an app restart: the grid renders from here without
/// the network, and even offline. Implementations scope entries to the
/// signed-in server + account — media ids are only unique per server — and
/// bound their own disk usage by evicting the least recently used entries.
abstract interface class MediaThumbnailCacheRepository {
  /// Cached bytes for media [id] at [size], or null when never fetched (or
  /// already evicted).
  Future<Uint8List?> find(MediaId id, {required int size});

  /// Stores [bytes] as the thumbnail of [id] at [size], fetched at
  /// [fetchedAt] (UTC).
  Future<void> save(
    MediaId id, {
    required int size,
    required Uint8List bytes,
    required DateTime fetchedAt,
  });
}
