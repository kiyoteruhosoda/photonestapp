/// Application port to the device's current network connection.
///
/// Auto-upload sends photo and video originals, so it needs to know whether
/// the bytes it is about to send are billed to the user. The platform's own
/// notion of "metered" is the one the background scheduler already enforces
/// (`NetworkType.unmetered`), so the foreground app asks the same question
/// here instead of inventing a second rule.
abstract interface class NetworkConnectionGateway {
  /// Whether the active connection is one the user is not billed per byte
  /// for — Wi-Fi or Ethernet in practice.
  ///
  /// False when offline, and false when the connection type cannot be
  /// established: the safe answer for a feature that would otherwise spend
  /// someone's mobile data allowance is "assume it costs".
  Future<bool> isUnmetered();
}
