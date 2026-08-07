import 'package:flutterbase/domain/errors/app_error.dart';

/// Identity of a stored bookmark.
///
/// Hand-written rather than generated: `equatable` is deliberately not a
/// dependency of this template, so value objects spell out their own [==]
/// and [hashCode]. See `docs/adr/0002-starter-stack.md`.
///
/// The constructor is the only place that decides what a valid id is, so an
/// id that reached the app from a deep link cannot be a negative number or a
/// zero row id by the time a use case sees it.
final class BookmarkId {
  /// Throws [DomainError] when [value] is not a positive row id.
  factory BookmarkId(int value) {
    if (value <= 0) {
      throw DomainError('BookmarkId must be positive, got $value.');
    }
    return BookmarkId._(value);
  }

  const BookmarkId._(this.value);

  /// Parses [raw] — typically a deep-link path segment — returning null when
  /// it does not describe a valid id.
  ///
  /// Deep links arrive from outside the app, so "unparseable" is an expected
  /// input rather than a programming error: the caller decides whether to
  /// show a not-found screen or ignore the link.
  static BookmarkId? tryParse(String? raw) {
    if (raw == null) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return BookmarkId._(parsed);
  }

  /// The underlying SQLite row id.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookmarkId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BookmarkId($value)';
}
