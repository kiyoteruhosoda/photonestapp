import 'package:flutterbase/domain/value_objects/album_id.dart';

/// Every location the app can be at, as `go_router` path patterns.
///
/// Lives in Presentation rather than next to the router itself so screens can
/// name a destination without importing the composition root — the arrow
/// `presentation → app` is rejected by `tool/check_architecture.dart`. The
/// router in `lib/app/bootstrap/app_router.dart` reads these same constants,
/// so there is one spelling of every path.
///
/// These paths are also the App Links contract: `/albums/42` is both an
/// in-app route and the tail of `https://<host>/albums/42`. Renaming one
/// renames the other, which is why they are constants and not string
/// literals scattered through the widgets.
class AppRoutes {
  AppRoutes._();

  /// Home, with the bottom navigation bar.
  static const String main = '/';

  /// Sign-in screen. The router redirects here while no session exists, and
  /// away from here once one does.
  static const String login = '/login';

  /// Path parameter naming the album on [albumDetail].
  static const String albumIdParam = 'id';

  /// One album's media grid — the deep-link target. The album list itself
  /// is the home tab. Build a concrete location with [albumDetailPath]
  /// rather than interpolating by hand.
  static const String albumDetail = '/albums/:$albumIdParam';

  static const String about = '/about';
  static const String debug = '/debug';
  static const String logs = '/logs';

  /// The notification list behind the header's bell button.
  static const String notifications = '/notifications';

  /// Diagnostics screen that echoes the link it was opened with.
  static const String deepLink = '/link';

  /// Concrete location of the album detail screen for [id].
  static String albumDetailPath(AlbumId id) => '/albums/${id.value}';
}
