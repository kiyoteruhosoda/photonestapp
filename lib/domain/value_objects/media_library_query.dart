/// What kind of media the reader wants to see.
///
/// `any` is the absence of a filter rather than a third kind, so it is the
/// default and never reaches the server as a parameter.
enum MediaKindFilter {
  any,
  photo,
  video;

  /// The value the server's `type` parameter expects, or null for "no filter".
  String? get queryValue => switch (this) {
    MediaKindFilter.any => null,
    MediaKindFilter.photo => 'photo',
    MediaKindFilter.video => 'video',
  };
}

/// How the reader has narrowed the library.
///
/// A value object rather than loose parameters: the timeline reloads from the
/// first window whenever it changes, so "did the narrowing change" has to be a
/// single comparison. Equality is by the fields, which is what makes that work.
final class MediaLibraryQuery {
  const MediaLibraryQuery({
    this.text = '',
    this.kind = MediaKindFilter.any,
    this.favoritesOnly = false,
  });

  /// Free text matched against filename, camera, caption and tag names.
  /// Blank means "no text filter" — the server is not asked to match `''`.
  final String text;

  final MediaKindFilter kind;

  /// Only media the reader marked as a favourite.
  final bool favoritesOnly;

  /// Nothing is narrowed — the plain chronological library.
  bool get isUnfiltered =>
      text.trim().isEmpty && kind == MediaKindFilter.any && !favoritesOnly;

  /// The text as it should be sent, or null when there is nothing to match.
  String? get searchText {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  MediaLibraryQuery copyWith({
    String? text,
    MediaKindFilter? kind,
    bool? favoritesOnly,
  }) {
    return MediaLibraryQuery(
      text: text ?? this.text,
      kind: kind ?? this.kind,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MediaLibraryQuery &&
      other.text == text &&
      other.kind == kind &&
      other.favoritesOnly == favoritesOnly;

  @override
  int get hashCode => Object.hash(text, kind, favoritesOnly);

  @override
  String toString() =>
      'MediaLibraryQuery(text: "$text", kind: ${kind.name}, '
      'favoritesOnly: $favoritesOnly)';
}
