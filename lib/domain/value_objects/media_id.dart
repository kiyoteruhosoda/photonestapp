import 'package:flutterbase/domain/errors/app_error.dart';

/// Identity of a media item (photo or video) stored on the PhotoNest server.
final class MediaId {
  /// Throws [DomainError] when [value] is not a positive server id.
  factory MediaId(int value) {
    if (value <= 0) {
      throw DomainError('MediaId must be positive, got $value.');
    }
    return MediaId._(value);
  }

  const MediaId._(this.value);

  /// Parses [raw], returning null when it does not describe a valid id.
  static MediaId? tryParse(String? raw) {
    if (raw == null) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return MediaId._(parsed);
  }

  /// The server-side media id.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MediaId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MediaId($value)';
}
