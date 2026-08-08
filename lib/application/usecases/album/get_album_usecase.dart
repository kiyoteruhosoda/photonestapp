import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/repositories/album_snapshot_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Loads one album with one page of its media, or null when it does not
/// exist, keeping the offline snapshot in step. The screen keeps asking for
/// the next [execute] `mediaPage` until it has accumulated `mediaTotal`
/// items — or, when the server reports no total, until a page comes back
/// short.
///
/// Server first: every fetched page replaces its snapshot, and an
/// unreachable server falls back to it — which is what lets an offline cold
/// start still render an album's grid from cached thumbnails. A null from
/// the server is an answer, not a failure: the album is gone, so its
/// snapshot pages are dropped rather than left to resurrect it offline.
/// Only infrastructure failures fall back; a rejected identity
/// ([AuthenticationError]) must surface. A broken snapshot store degrades
/// to server-only behaviour — those failures are logged and swallowed here,
/// deliberately, like the thumbnail cache's.
final class GetAlbumUseCase {
  const GetAlbumUseCase(this._albums, this._snapshots, this._logger);

  final AlbumRepository _albums;
  final AlbumSnapshotRepository _snapshots;
  final AppLogger _logger;

  Future<AlbumDetail?> execute(
    AlbumId id, {
    int mediaPage = 1,
    int mediaPageSize = 100,
  }) async {
    final AlbumDetail? detail;
    try {
      detail = await _albums.findById(
        id,
        mediaPage: mediaPage,
        mediaPageSize: mediaPageSize,
      );
    } on InfrastructureError catch (error) {
      final snapshot = await _findSnapshot(id, mediaPage, mediaPageSize);
      if (snapshot != null) {
        _logger.warning(
          '[Album] detail fetch failed (${error.message}) — '
          'serving the offline snapshot of album ${id.value} page $mediaPage',
        );
        return snapshot;
      }
      rethrow;
    }
    try {
      if (detail == null) {
        await _snapshots.removeDetail(id);
      } else {
        await _snapshots.saveDetail(
          detail,
          mediaPage: mediaPage,
          mediaPageSize: mediaPageSize,
        );
      }
    } on AppError catch (error) {
      _logger.warning('[Album] detail snapshot write failed: ${error.message}');
    }
    return detail;
  }

  Future<AlbumDetail?> _findSnapshot(
    AlbumId id,
    int mediaPage,
    int mediaPageSize,
  ) async {
    try {
      return await _snapshots.findDetail(
        id,
        mediaPage: mediaPage,
        mediaPageSize: mediaPageSize,
      );
    } on AppError catch (error) {
      _logger.warning('[Album] detail snapshot read failed: ${error.message}');
      return null;
    }
  }
}
