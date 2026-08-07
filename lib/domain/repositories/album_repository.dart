import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Boundary to the server's album endpoints.
abstract interface class AlbumRepository {
  /// All albums visible to the signed-in user, in the server's order.
  Future<List<Album>> findAll();

  /// The album [id] with its media, or null when it does not exist (or is
  /// no longer visible).
  Future<AlbumDetail?> findById(AlbumId id);
}
