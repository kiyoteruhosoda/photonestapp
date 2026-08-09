import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:photonest/application/ports/network_connection_gateway.dart';

/// [NetworkConnectionGateway] backed by the `connectivity_plus` plugin.
///
/// The plugin reports the *transports* the active network runs over, not the
/// platform's metered flag, so "unmetered" is read as "Wi-Fi or Ethernet is
/// one of them". Two consequences worth knowing:
///
/// - A Wi-Fi network the user marked as metered still counts as unmetered
///   here, while WorkManager's `NetworkType.unmetered` constraint correctly
///   refuses it. The background pass is therefore the stricter of the two.
/// - A VPN reports the transports of the network underneath it as well
///   (`[wifi, vpn]`), so an always-on VPN over Wi-Fi is still recognised.
final class ConnectivityPlusNetworkConnectionGateway
    implements NetworkConnectionGateway {
  const ConnectivityPlusNetworkConnectionGateway();

  @override
  Future<bool> isUnmetered() async {
    final transports = await Connectivity().checkConnectivity();
    return transports.any(_isFreeOfDataCharges);
  }

  static bool _isFreeOfDataCharges(ConnectivityResult transport) =>
      switch (transport) {
        ConnectivityResult.wifi || ConnectivityResult.ethernet => true,
        // Everything else — mobile, bluetooth, satellite, vpn on its own,
        // `other`, and `none` — either costs money or cannot be shown not to.
        _ => false,
      };
}
