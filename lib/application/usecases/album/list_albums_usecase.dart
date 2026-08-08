import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/repositories/album_snapshot_repository.dart';

/// Lists the albums visible to the signed-in user, keeping the offline
/// snapshot in step.
///
/// Server first: every successful fetch replaces the snapshot, and an
/// unreachable server falls back to it — which is what lets an offline cold
/// start still show the album list over cached thumbnails. Only
/// infrastructure failures fall back; a rejected identity
/// ([AuthenticationError]) must surface, because a snapshot would dress a
/// signed-out app up as signed in. A broken snapshot store degrades to
/// server-only behaviour — those failures are logged and swallowed here,
/// deliberately, like the thumbnail cache's.
final class ListAlbumsUseCase {
  const ListAlbumsUseCase(this._albums, this._snapshots, this._logger);

  final AlbumRepository _albums;
  final AlbumSnapshotRepository _snapshots;
  final AppLogger _logger;

  Future<List<Album>> execute() async {
    final List<Album> albums;
    try {
      albums = await _albums.findAll();
    } on InfrastructureError catch (error) {
      final snapshot = await _findSnapshot();
      if (snapshot != null) {
        _logger.warning(
          '[Album] list fetch failed (${error.message}) — '
          'serving the offline snapshot',
        );
        return snapshot;
      }
      rethrow;
    }
    try {
      await _snapshots.saveAlbums(albums);
    } on AppError catch (error) {
      _logger.warning('[Album] list snapshot write failed: ${error.message}');
    }
    return albums;
  }

  Future<List<Album>?> _findSnapshot() async {
    try {
      return await _snapshots.findAlbums();
    } on AppError catch (error) {
      _logger.warning('[Album] list snapshot read failed: ${error.message}');
      return null;
    }
  }
}
