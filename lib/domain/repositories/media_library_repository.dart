import 'package:flutterbase/domain/entities/media_library_page.dart';

/// Boundary to the server's whole-library media listing.
///
/// Distinct from the album repository: albums are curated subsets, this is
/// everything the signed-in user can see, in capture order. A photo that was
/// never put in an album is only reachable through here.
abstract interface class MediaLibraryRepository {
  /// The [page]-th window of [pageSize] media items (1-based), newest
  /// capture first.
  Future<MediaLibraryPage> findPage({int page = 1, int pageSize = 100});
}
