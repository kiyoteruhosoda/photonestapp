import 'package:flutterbase/domain/errors/app_error.dart';

/// Identity of an album stored on the PhotoNest server.
///
/// The constructor is the only place that decides what a valid id is, so an
/// id that reached the app from a deep link or an API payload cannot be a
/// negative number by the time a use case sees it.
final class AlbumId {
  /// Throws [DomainError] when [value] is not a positive server id.
  factory AlbumId(int value) {
    if (value <= 0) {
      throw DomainError('AlbumId must be positive, got $value.');
    }
    return AlbumId._(value);
  }

  const AlbumId._(this.value);

  /// Parses [raw] — typically a route path segment — returning null when it
  /// does not describe a valid id.
  static AlbumId? tryParse(String? raw) {
    if (raw == null) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return AlbumId._(parsed);
  }

  /// The server-side album id.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlbumId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AlbumId($value)';
}
