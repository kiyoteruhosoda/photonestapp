import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/shared/app_config.dart';

void main() {
  group('AppRoutes', () {
    test('every location is absolute', () {
      for (final path in <String>[
        AppRoutes.main,
        AppRoutes.about,
        AppRoutes.debug,
        AppRoutes.logs,
        AppRoutes.bookmarks,
        AppRoutes.bookmarkDetail,
        AppRoutes.deepLink,
      ]) {
        expect(path, startsWith('/'), reason: '$path must be absolute');
      }
    });

    test('the detail pattern uses the parameter name the router reads', () {
      expect(
        AppRoutes.bookmarkDetail,
        '/bookmarks/:${AppRoutes.bookmarkIdParam}',
      );
    });

    test('bookmarkDetailPath builds a location the pattern matches', () {
      expect(AppRoutes.bookmarkDetailPath(BookmarkId(42)), '/bookmarks/42');
    });
  });

  group('deep-link URLs', () {
    test('an App Link is https on the configured host', () {
      final link = AppConfig.appLink(
        AppRoutes.bookmarkDetailPath(BookmarkId(1)),
      );

      expect(link.scheme, 'https');
      expect(link.host, AppConfig.appLinkHost);
      expect(link.path, '/bookmarks/1');
    });

    test('a custom-scheme link keeps the whole path in the path', () {
      // Android's Flutter embedding routes on the URI path and drops the
      // authority, so the empty-authority form is what makes
      // flutterbase:///bookmarks/1 land on the same route as the App Link.
      final link = AppConfig.customLink('/bookmarks/1');

      expect(link.scheme, AppConfig.customLinkScheme);
      expect(link.host, isEmpty);
      expect(link.path, '/bookmarks/1');
    });

    test('both forms resolve to the same in-app location', () {
      const path = '/bookmarks/1';
      expect(AppConfig.appLink(path).path, AppConfig.customLink(path).path);
    });
  });
}
