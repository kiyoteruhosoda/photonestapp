import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

/// Every location the app can be at, as `go_router` path patterns.
///
/// Lives in Presentation rather than next to the router itself so screens can
/// name a destination without importing the composition root — the arrow
/// `presentation → app` is rejected by `tool/check_architecture.dart`. The
/// router in `lib/app/bootstrap/app_router.dart` reads these same constants,
/// so there is one spelling of every path.
///
/// These paths are also the App Links contract: `/bookmarks/42` is both an
/// in-app route and the tail of `https://<host>/bookmarks/42`. Renaming one
/// renames the other, which is why they are constants and not string
/// literals scattered through the widgets.
class AppRoutes {
  AppRoutes._();

  /// Home, with the bottom navigation bar.
  static const String main = '/';

  static const String about = '/about';
  static const String debug = '/debug';
  static const String logs = '/logs';

  /// The bookmarks sample feature.
  static const String bookmarks = '/bookmarks';

  /// Path parameter naming the bookmark on [bookmarkDetail].
  static const String bookmarkIdParam = 'id';

  /// Detail screen — the deep-link target. Build one with
  /// [bookmarkDetailPath] rather than interpolating by hand.
  static const String bookmarkDetail = '/bookmarks/:$bookmarkIdParam';

  /// Diagnostics screen that echoes the link it was opened with.
  static const String deepLink = '/link';

  /// Concrete location of the detail screen for [id].
  static String bookmarkDetailPath(BookmarkId id) => '$bookmarks/${id.value}';
}
