import 'package:flutterbase/domain/value_objects/media_id.dart';

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
  });

  final MediaId id;
  final String filename;

  /// Capture instant in UTC, when the server knows it.
  final DateTime? shotAt;

  /// True when the item is a video — the grid shows a play badge and taps
  /// open the player instead of the still-image viewer.
  final bool isVideo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MediaItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MediaItem(${id.value}, $filename)';
}
