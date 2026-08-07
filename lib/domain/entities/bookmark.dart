import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

/// Maximum number of characters a bookmark title may hold.
const int maxBookmarkTitleLength = 120;

/// Schemes a bookmark may point at.
///
/// Anything else — `file:`, `javascript:`, an app's own custom scheme — would
/// be handed to the platform's link launcher, so the domain refuses it here
/// rather than letting Infrastructure decide.
const Set<String> allowedBookmarkSchemes = {'http', 'https'};

/// A bookmark the user has composed but that has not been stored yet.
///
/// Separating the draft from [Bookmark] keeps the identity rule honest: an id
/// exists only once the repository has assigned one, so no code has to carry a
/// nullable id around or invent a placeholder.
final class BookmarkDraft {
  /// Validates and normalises user input.
  ///
  /// Throws [DomainError] when the title is blank or too long, or when the
  /// URL is not an absolute `http`/`https` address.
  factory BookmarkDraft({required String title, required Uri url}) {
    final normalisedTitle = title.trim();
    if (normalisedTitle.isEmpty) {
      throw const DomainError('Bookmark title must not be blank.');
    }
    if (normalisedTitle.length > maxBookmarkTitleLength) {
      throw const DomainError(
        'Bookmark title must be at most $maxBookmarkTitleLength characters.',
      );
    }
    if (!url.hasScheme || !allowedBookmarkSchemes.contains(url.scheme)) {
      throw DomainError('Bookmark URL must be http or https, got "$url".');
    }
    if (url.host.isEmpty) {
      throw DomainError('Bookmark URL must have a host, got "$url".');
    }
    return BookmarkDraft._(title: normalisedTitle, url: url);
  }

  const BookmarkDraft._({required this.title, required this.url});

  /// Trimmed, non-empty label shown in lists.
  final String title;

  /// Absolute `http`/`https` address the bookmark points at.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkDraft && other.title == title && other.url == url);

  @override
  int get hashCode => Object.hash(title, url);

  @override
  String toString() => 'BookmarkDraft($title, $url)';
}

/// A stored bookmark.
///
/// Two bookmarks are the same when their [id] is the same — this is an
/// entity, not a value object, so a renamed bookmark is still the same
/// bookmark. Compare [BookmarkDraft] instead when field-by-field equality is
/// what you want.
final class Bookmark {
  const Bookmark({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  /// Assigns [id] and [createdAt] to a validated [draft].
  ///
  /// Called by the repository once storage has produced a row id, so the
  /// validation rules in [BookmarkDraft] are the only way to build one.
  factory Bookmark.fromDraft({
    required BookmarkId id,
    required BookmarkDraft draft,
    required DateTime createdAt,
  }) {
    return Bookmark(
      id: id,
      title: draft.title,
      url: draft.url,
      createdAt: createdAt.toUtc(),
    );
  }

  final BookmarkId id;
  final String title;
  final Uri url;

  /// Creation instant, always in UTC. The Presentation layer converts it to
  /// the viewer's time zone — see `.claude/skills/i18n-time.md`.
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Bookmark && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Bookmark(${id.value}, $title)';
}
