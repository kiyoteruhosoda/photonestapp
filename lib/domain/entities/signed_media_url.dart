/// A signed, short-lived URL the server issued for one media file.
///
/// The URL embeds its own authorisation, so a player, an image widget, or a
/// browser can be handed it directly without carrying the API session.
/// Expired URLs are simply requested again.
///
/// The same shape serves both endpoints that issue one: the streaming
/// rendition (`playback-url`) and the untouched original (`original-url`).
final class SignedMediaUrl {
  const SignedMediaUrl({required this.url, this.expiresAt});

  /// Absolute URL of the media file.
  final Uri url;

  /// Instant (UTC) after which [url] stops working, when the server said.
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignedMediaUrl &&
          other.url == url &&
          other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(url, expiresAt);

  @override
  String toString() => 'SignedMediaUrl($url)';
}
