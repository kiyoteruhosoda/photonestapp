import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Loads one album with its media, or null when it does not exist.
final class GetAlbumUseCase {
  const GetAlbumUseCase(this._albums);

  final AlbumRepository _albums;

  Future<AlbumDetail?> execute(AlbumId id) => _albums.findById(id);
}
