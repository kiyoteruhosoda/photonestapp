import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';

/// Lists the albums visible to the signed-in user.
final class ListAlbumsUseCase {
  const ListAlbumsUseCase(this._albums);

  final AlbumRepository _albums;

  Future<List<Album>> execute() => _albums.findAll();
}
