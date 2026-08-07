import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_detail_page.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
import 'package:flutterbase/presentation/pages/main_page.dart';
import 'package:flutterbase/presentation/pages/system/about_page.dart';
import 'package:flutterbase/presentation/pages/system/debug_page.dart';
import 'package:flutterbase/presentation/pages/system/deep_link_page.dart';
import 'package:flutterbase/presentation/pages/system/logs_page.dart';
import 'package:flutterbase/presentation/pages/system/not_found_page.dart';
import 'package:go_router/go_router.dart';

/// Builds the app's [GoRouter].
///
/// Routing lives in the composition root because it is the one place allowed
/// to name every screen at once. Screens navigate by the constants in
/// `presentation/navigation/app_routes.dart` and never import this file —
/// `presentation → app` is a rejected direction.
///
/// ## Why go_router, and what it has to do with App Links
///
/// The Router API is what turns an incoming platform link into an ordinary
/// navigation event: Android hands Flutter the *path* of the tapped URL and
/// [GoRouter] matches it against [create]'s route table exactly as if the app
/// had navigated there itself. That is the whole deep-link mechanism — there
/// is no second link handler to keep in sync, which is why the route table
/// and the published URL structure are deliberately the same strings.
///
/// The Android half of the contract lives in `AndroidManifest.xml`
/// (`flutter_deeplinking_enabled` plus the `autoVerify` intent filter) and in
/// the `assetlinks.json` served by the domain. See `docs/DEEP_LINKS.md`.
class AppRouter {
  AppRouter._();

  /// Creates the router.
  ///
  /// Call once per app run and hold the result: building a new [GoRouter] on
  /// every rebuild would reset the navigation stack. [initialLocation] exists
  /// for tests that want to start somewhere other than Home — at runtime the
  /// platform's deep link wins over it.
  static GoRouter create({required AppLogger logger, String? initialLocation}) {
    return GoRouter(
      initialLocation: initialLocation ?? AppRoutes.main,
      // Every resolved location passes through here — including the one the
      // platform hands over when a link launches the app cold — so one log
      // line answers "did the link reach the router, and as what?".
      redirect: (context, state) {
        logger.debug('[Router] → ${state.uri}');
        return null;
      },
      errorBuilder: (context, state) => NotFoundPage(uri: state.uri),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.main,
          builder: (context, state) => const MainPage(),
          // Declared as children of `/` so every screen has Home beneath it:
          // a cold start from a deep link still leaves somewhere to go back
          // to instead of a dead-end stack of one.
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoutes.about),
              builder: (context, state) => const AboutPage(),
            ),
            GoRoute(
              path: _relative(AppRoutes.debug),
              builder: (context, state) => const DebugPage(),
            ),
            GoRoute(
              path: _relative(AppRoutes.logs),
              builder: (context, state) => const LogsPage(),
            ),
            GoRoute(
              path: _relative(AppRoutes.deepLink),
              builder: (context, state) => DeepLinkPage(uri: state.uri),
            ),
            GoRoute(
              path: _relative(AppRoutes.bookmarks),
              builder: (context, state) => const BookmarksPage(),
              routes: <RouteBase>[
                GoRoute(
                  // The deep-link target. `tryParse` returns null for
                  // anything that is not a positive integer and the page
                  // renders its not-found state: a link from outside the app
                  // is input, not a promise.
                  path: ':${AppRoutes.bookmarkIdParam}',
                  builder: (context, state) => BookmarkDetailPage(
                    id: BookmarkId.tryParse(
                      state.pathParameters[AppRoutes.bookmarkIdParam],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Strips the leading slash so a top-level path can be declared as a child
  /// of `/`.
  static String _relative(String path) =>
      path.startsWith('/') ? path.substring(1) : path;
}
