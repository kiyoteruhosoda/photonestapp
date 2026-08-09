import 'package:photonest/domain/errors/app_error.dart';

/// Identity of a tag held by the PhotoNest server.
final class TagId {
  /// Throws [DomainError] when [value] is not a positive server id.
  factory TagId(int value) {
    if (value <= 0) {
      throw DomainError('TagId must be positive, got $value.');
    }
    return TagId._(value);
  }

  const TagId._(this.value);

  /// The server-side tag id.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TagId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TagId($value)';
}
