/// Hands a URL to whatever the platform considers its owner — a browser, a
/// mail client, another app that has registered the link.
///
/// An outbound port: the Application layer states what it needs, and
/// `infrastructure/links/` supplies the `url_launcher` implementation. Keeping
/// it behind a port is what lets a use case be tested without a platform
/// channel, and what stops a plugin call from leaking into a widget.
abstract interface class ExternalLinkLauncher {
  /// Opens [url] outside the app.
  ///
  /// Returns false when no installed application can handle it, which is an
  /// expected outcome the caller reports to the user — not a failure.
  Future<bool> open(Uri url);
}
