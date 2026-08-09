import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/value_objects/album_id.dart';

/// Local, persistent snapshot of the album metadata the server last
/// returned: the album list, and each detail page that was fetched.
///
/// The thumbnail cache already keeps the *pixels* offline; this keeps the
/// *structure* — which albums exist and which media each one holds — so an
/// offline cold start can still lay out the list and the grid and let the
/// cached thumbnails fill them. Readers treat the snapshot as a fallback
/// for a failed fetch, never as the primary source.
///
/// Implementations scope entries to the signed-in server + account — album
/// and media ids are only unique per server — and answer null instead of
/// failing while signed out.
abstract interface class AlbumSnapshotRepository {
  /// Remembers [albums] as the album list, replacing the previous snapshot.
  ///
  /// An empty list is a real answer ("this account has no albums") and is
  /// remembered as such, distinct from never having saved at all.
  ///
  /// A full list is authoritative: detail pages of albums the list no
  /// longer holds (deleted or no longer visible) are forgotten in the same
  /// save, so an offline detail read — a deep link never consults the list
  /// — cannot resurrect them.
  Future<void> saveAlbums(List<Album> albums);

  /// The album list as last saved, or null when no snapshot exists (or
  /// nobody is signed in).
  Future<List<Album>?> findAlbums();

  /// Remembers [detail] as the [mediaPage]-th window of [mediaPageSize]
  /// media items of its album, replacing that page's previous snapshot.
  Future<void> saveDetail(
    AlbumDetail detail, {
    required int mediaPage,
    required int mediaPageSize,
  });

  /// The saved detail page of album [id], or null when that page was never
  /// saved (or nobody is signed in).
  Future<AlbumDetail?> findDetail(
    AlbumId id, {
    required int mediaPage,
    required int mediaPageSize,
  });

  /// Forgets every saved detail page of album [id] — the server said the
  /// album no longer exists, and an offline read must not resurrect it.
  Future<void> removeDetail(AlbumId id);
}
