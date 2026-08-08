import 'package:flutterbase/domain/value_objects/media_id.dart';

/// One media item inside an album, as the album detail endpoint reports it.
final class AlbumMediaItem {
  const AlbumMediaItem({
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
      identical(this, other) || (other is AlbumMediaItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AlbumMediaItem(${id.value}, $filename)';
}
