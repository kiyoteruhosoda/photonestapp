/// Where a video can be streamed from, as issued by the server.
///
/// The URL is signed and short-lived: it embeds its own authorisation, so a
/// player can hand it straight to the platform without carrying the API
/// session. Expired sources are simply requested again.
final class MediaPlaybackSource {
  const MediaPlaybackSource({required this.url, this.expiresAt});

  /// Absolute streaming URL.
  final Uri url;

  /// Instant (UTC) after which [url] stops working, when the server said.
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaPlaybackSource &&
          other.url == url &&
          other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(url, expiresAt);

  @override
  String toString() => 'MediaPlaybackSource($url)';
}
