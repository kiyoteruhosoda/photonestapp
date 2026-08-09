import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';

/// Boundary to the server's whole-library media listing.
///
/// Distinct from the album repository: albums are curated subsets, this is
/// everything the signed-in user can see, in capture order. A photo that was
/// never put in an album is only reachable through here.
abstract interface class MediaLibraryRepository {
  /// A window of up to [pageSize] media items, newest capture first.
  ///
  /// Pass the previous page's `nextCursor` as [cursor] to continue; omit it
  /// for the first window. Cursor (keyset) paging is used rather than an
  /// offset so that media added or removed mid-scroll cannot make the
  /// timeline skip or repeat items, and so deep positions stay cheap.
  ///
  /// [query] narrows what the windows are cut from. Changing it invalidates
  /// any cursor taken under the previous one.
  Future<MediaLibraryPage> findPage({
    String? cursor,
    int pageSize = 100,
    MediaLibraryQuery query = const MediaLibraryQuery(),
  });

  /// A window of the trash — media moved there but not yet purged.
  ///
  /// A separate method rather than a flag on [findPage]: the trash is a
  /// different list with different actions (restore, not open), and mixing
  /// the two behind one call has already produced screens that show deleted
  /// media by accident.
  Future<MediaLibraryPage> findTrashPage({String? cursor, int pageSize = 100});
}
