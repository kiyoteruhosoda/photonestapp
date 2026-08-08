import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Loads one album with one page of its media, or null when it does not
/// exist. The screen keeps asking for the next [mediaPage] until it has
/// accumulated `mediaTotal` items.
final class GetAlbumUseCase {
  const GetAlbumUseCase(this._albums);

  final AlbumRepository _albums;

  Future<AlbumDetail?> execute(
    AlbumId id, {
    int mediaPage = 1,
    int mediaPageSize = 100,
  }) =>
      _albums.findById(id, mediaPage: mediaPage, mediaPageSize: mediaPageSize);
}
