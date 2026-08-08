import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/repositories/album_snapshot_repository.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';

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
///
/// The signed-in identity is captured before the fetch is dispatched: the
/// snapshot store scopes rows to whoever is signed in *now*, so if the user
/// switches account (or signs out) while the request is in flight, touching
/// the snapshot afterwards would file one account's albums under another's
/// key — or serve them from it. When the identity has changed by the time
/// the response lands, the snapshot is neither written nor served.
final class ListAlbumsUseCase {
  const ListAlbumsUseCase(
    this._albums,
    this._snapshots,
    this._sessions,
    this._endpoints,
    this._logger,
  );

  final AlbumRepository _albums;
  final AlbumSnapshotRepository _snapshots;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;
  final AppLogger _logger;

  Future<List<Album>> execute() async {
    final requester = _signedInIdentity();
    final List<Album> albums;
    try {
      albums = await _albums.findAll();
    } on InfrastructureError catch (error) {
      if (_signedInIdentity() != requester) {
        _logger.warning(
          '[Album] identity changed mid-fetch — '
          'not serving the list snapshot',
        );
        rethrow;
      }
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
    if (_signedInIdentity() != requester) {
      _logger.warning(
        '[Album] identity changed mid-fetch — list snapshot not written',
      );
      return albums;
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

  /// Who is signed in right now — the same (server, account) pair the
  /// snapshot store scopes its rows by.
  ({String? email, Uri? server}) _signedInIdentity() =>
      (email: _sessions.load()?.email, server: _endpoints.load());
}
