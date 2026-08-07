import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// [ExternalLinkLauncher] backed by the `url_launcher` plugin.
///
/// [LaunchMode.externalApplication] is deliberate: a bookmark should leave the
/// app and land in the browser (or in whichever app has verified the domain),
/// not in an in-app web view that hides the address bar.
final class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlLauncherExternalLinkLauncher();

  @override
  Future<bool> open(Uri url) async {
    if (!await canLaunchUrl(url)) return false;
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
