/// Single source of truth for per-app identity values that live in Dart.
///
/// When forking the template for a new app, edit the values in this file
/// and follow `docs/CUSTOMISATION.md` for the surfaces that cannot be
/// centralised here (bundle IDs, launcher icons, font binaries).
///
/// Conventions (mirrors [AppColors]):
///   - `class` + private ctor + `static const` fields
///   - no state, no DI, importable anywhere
class AppConfig {
  AppConfig._();

  // ─── Identity ─────────────────────────────────────────────────────
  /// Display name shown in the MaterialApp title, drawer header,
  /// and About page.
  static const String appName = 'PhotoNest';

  /// One-line description shown on the About page.
  static const String appDescription =
      'Mobile client for the PhotoNest photo library';

  /// Short tagline rendered under the app name in the drawer.
  static const String appTagline = 'Your photos, in your nest';

  // ─── Home page copy ───────────────────────────────────────────────
  static const String homeSubtitle = 'PhotoNest';
  static const String homeCardTitle = 'PhotoNest';

  // ─── Deep links (App Links) ───────────────────────────────────────
  /// Domain that Android verifies against
  /// `https://<appLinkHost>/.well-known/assetlinks.json`.
  ///
  /// Must match the `android:host` of the `autoVerify` intent filter in
  /// `android/app/src/main/AndroidManifest.xml`. Change both together, or
  /// verification silently fails and links open in the browser instead.
  /// See `docs/DEEP_LINKS.md`.
  ///
  /// This is the PhotoNest server itself, which also serves the web SPA, so
  /// an album link opens in the app when it is installed and in the browser
  /// when it is not. The manifest claims only the paths the app routes —
  /// [appLink] can build a URL the filter does not cover.
  static const String appLinkHost = 'photonest.nolumia.com';

  /// Scheme of the verified App Link. Android only verifies `https`.
  static const String appLinkScheme = 'https';

  /// Unverified fallback scheme, e.g. `photonest://albums/1`.
  ///
  /// Any app may claim a custom scheme, so this is for local testing and for
  /// platforms without App Links — never for links a stranger can send.
  static const String customLinkScheme = 'photonest';

  /// The verified `https` link that opens [path] inside the app.
  static Uri appLink(String path) =>
      Uri.parse('$appLinkScheme://$appLinkHost$path');

  /// The custom-scheme equivalent of [appLink].
  ///
  /// Produces the three-slash form (`photonest:///albums/1`) on purpose.
  /// Android's Flutter embedding builds the in-app route from the incoming
  /// URI's *path* and discards its authority, so `photonest://albums/1`
  /// would arrive as the route `/1` — with an empty authority the whole
  /// `/albums/1` survives and matches the same route the App Link does.
  static Uri customLink(String path) => Uri.parse('$customLinkScheme://$path');

  // ─── Typography ───────────────────────────────────────────────────
  /// Must exactly match the `family:` entry in `pubspec.yaml`'s fonts
  /// section. Both values are the contract between Flutter's font loader
  /// and the declared assets — drift causes silent fallback to system fonts.
  static const String fontFamily = 'NotoSansJP';

  // ─── Design system attribution (About + LicenseRegistry) ──────────
  static const String designSystemLabel = 'DADS v2.10.3';
  static const String designSystemName = 'Digital Agency Design System (DADS)';
  static const String designSystemUrl = 'https://design.digital.go.jp/';
  static const String designSystemLicense = 'CC BY 4.0';
}
