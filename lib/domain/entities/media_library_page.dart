import 'package:photonest/domain/entities/media_item.dart';

/// One window of the whole media library, as the library listing endpoint
/// returns it.
///
/// The library has no meaningful total — it grows while it is being read —
/// so the server answers "is there another page" instead of a count, and
/// [hasNext] is what a reader pages on.
final class MediaLibraryPage {
  const MediaLibraryPage({required this.items, required this.hasNext});

  /// The page's media, newest capture first.
  final List<MediaItem> items;

  /// Whether the server holds media beyond this page.
  final bool hasNext;

  @override
  String toString() =>
      'MediaLibraryPage(${items.length} items, '
      'hasNext: $hasNext)';
}
