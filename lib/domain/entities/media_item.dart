import 'package:photonest/domain/value_objects/media_id.dart';

/// One photo or video held by the server, as its listing endpoints report
/// it.
///
/// The same shape serves the album detail grid and the whole-library
/// timeline: both list media, and neither needs more than this to render a
/// tile and open a viewer.
final class MediaItem {
  const MediaItem({
    required this.id,
    required this.filename,
    this.shotAt,
    this.isVideo = false,
    this.isFavorite = false,
    this.isDeleted = false,
  });

  final MediaId id;
  final String filename;

  /// Capture instant in UTC, when the server knows it.
  final DateTime? shotAt;

  /// True when the item is a video — the grid shows a play badge and taps
  /// open the player instead of the still-image viewer.
  final bool isVideo;

  /// Marked as a favourite by someone signed in to this library.
  final bool isFavorite;

  /// In the trash. Restorable until the server purges the file (ADR-0018 on
  /// the server side); the app only ever sees these in the trash view.
  final bool isDeleted;

  /// The same media with [isFavorite] flipped — what the viewer renders
  /// while the server confirms.
  MediaItem withFavorite(bool favorite) => MediaItem(
    id: id,
    filename: filename,
    shotAt: shotAt,
    isVideo: isVideo,
    isFavorite: favorite,
    isDeleted: isDeleted,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MediaItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MediaItem(${id.value}, $filename'
      '${isFavorite ? ', favorite' : ''}${isDeleted ? ', deleted' : ''})';
}
