import 'package:photonest/domain/entities/media_item.dart';

/// One window of the whole media library, as the library listing endpoint
/// returns it.
///
/// The library has no meaningful total — it grows while it is being read —
/// so the server answers with a cursor to the next window instead of a
/// count, and [nextCursor] is what a reader pages on.
final class MediaLibraryPage {
  const MediaLibraryPage({required this.items, required this.nextCursor});

  /// The page's media, newest capture first.
  final List<MediaItem> items;

  /// Opaque position to pass back for the following window, or null when
  /// this page is the end. The server only sends one when more media
  /// follows, so its presence *is* the "has more" answer.
  final String? nextCursor;

  /// Whether the server holds media beyond this page.
  bool get hasNext => nextCursor != null;

  @override
  String toString() =>
      'MediaLibraryPage(${items.length} items, '
      'nextCursor: $nextCursor)';
}
