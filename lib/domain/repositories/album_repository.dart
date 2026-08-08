import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Boundary to the server's album endpoints.
abstract interface class AlbumRepository {
  /// All albums visible to the signed-in user, in the server's order —
  /// implementations follow the server's paging until the list is complete.
  Future<List<Album>> findAll();

  /// The album [id] with the [mediaPage]-th window of [mediaPageSize] media
  /// items (1-based), or null when the album does not exist (or is no
  /// longer visible).
  ///
  /// The returned detail carries the album's total media count, so a caller
  /// keeps requesting pages until it has accumulated that many items.
  Future<AlbumDetail?> findById(
    AlbumId id, {
    int mediaPage = 1,
    int mediaPageSize = 100,
  });
}
