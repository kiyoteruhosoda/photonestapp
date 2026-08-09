import 'dart:async';

import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/repositories/media_thumbnail_url_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Collects the thumbnails asked for in one go and issues their signed URLs
/// together.
///
/// A grid builds its visible tiles in a single frame, and each tile asks for
/// its own thumbnail. Issuing one URL per tile means dozens of authenticated
/// round trips to the app server for one screen; issuing them together means
/// one, after which the bytes come from the reverse proxy or a CDN edge.
///
/// The wait is [flushDelay] — zero by default, which is "after the current
/// frame's work" rather than a timed debounce. Callers that arrive while a
/// batch is in flight join the next one rather than waiting for it.
final class ThumbnailUrlBatch {
  ThumbnailUrlBatch(
    this._urls,
    this._logger, {
    this.flushDelay = Duration.zero,
    this.maxBatchSize = maxThumbnailUrlBatchSize,
  });

  final MediaThumbnailUrlRepository _urls;
  final AppLogger _logger;

  /// How long to keep collecting before issuing. Zero drains once the
  /// current synchronous work (a frame's builds) is done.
  final Duration flushDelay;

  /// Upper bound per request; the server refuses more.
  final int maxBatchSize;

  /// Requests waiting for the next flush, keyed by (id, size).
  final Map<(MediaId, int), Completer<SignedMediaUrl?>> _pending = {};
  Timer? _flushTimer;

  /// The signed URL for one thumbnail, or null when the server would not
  /// issue one (deleted or purged media, or the request failed).
  ///
  /// Never throws: a missing URL is answered as null so the caller can fall
  /// back to fetching through the app server.
  Future<SignedMediaUrl?> urlFor(MediaId id, {required int size}) {
    final key = (id, size);
    final existing = _pending[key];
    if (existing != null) return existing.future;

    final completer = Completer<SignedMediaUrl?>();
    _pending[key] = completer;
    _flushTimer ??= Timer(flushDelay, _flush);
    return completer.future;
  }

  void _flush() {
    _flushTimer = null;
    if (_pending.isEmpty) return;
    // Take the whole queue now: requests arriving during the round trip
    // belong to the next batch, not this one.
    final taken = Map.of(_pending);
    _pending.clear();

    // One request per size — the endpoint issues a single size at a time.
    final bySize = <int, List<MediaId>>{};
    for (final (id, size) in taken.keys) {
      bySize.putIfAbsent(size, () => <MediaId>[]).add(id);
    }
    for (final entry in bySize.entries) {
      for (final chunk in _chunked(entry.value, maxBatchSize)) {
        unawaited(_issue(chunk, entry.key, taken));
      }
    }
  }

  Future<void> _issue(
    List<MediaId> ids,
    int size,
    Map<(MediaId, int), Completer<SignedMediaUrl?>> waiting,
  ) async {
    Map<MediaId, SignedMediaUrl> issued;
    try {
      issued = await _urls.issue(ids, size: size);
    } on Object catch (error) {
      // The batch failing is not the tile's failure: each waiter falls back
      // to the per-media endpoint, which still renders the grid.
      _logger.warning('[Thumbnail] URL batch of ${ids.length} failed: $error');
      issued = const <MediaId, SignedMediaUrl>{};
    }
    for (final id in ids) {
      waiting[(id, size)]?.complete(issued[id]);
    }
  }

  static Iterable<List<T>> _chunked<T>(List<T> items, int size) sync* {
    for (var start = 0; start < items.length; start += size) {
      final end = start + size;
      yield items.sublist(start, end < items.length ? end : items.length);
    }
  }
}
