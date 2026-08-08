import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
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
        AppRoutes.albumDetail,
        AppRoutes.deepLink,
      ]) {
        expect(path, startsWith('/'), reason: '$path must be absolute');
      }
    });

    test('the detail pattern uses the parameter name the router reads', () {
      expect(AppRoutes.albumDetail, '/albums/:${AppRoutes.albumIdParam}');
    });

    test('albumDetailPath builds a location the pattern matches', () {
      expect(AppRoutes.albumDetailPath(AlbumId(42)), '/albums/42');
    });
  });

  group('deep-link URLs', () {
    test('an App Link is https on the configured host', () {
      final link = AppConfig.appLink(AppRoutes.albumDetailPath(AlbumId(1)));

      expect(link.scheme, 'https');
      expect(link.host, AppConfig.appLinkHost);
      expect(link.path, '/albums/1');
    });

    test('a custom-scheme link keeps the whole path in the path', () {
      // Android's Flutter embedding routes on the URI path and drops the
      // authority, so the empty-authority form is what makes
      // flutterbase:///albums/1 land on the same route as the App Link.
      final link = AppConfig.customLink('/albums/1');

      expect(link.scheme, AppConfig.customLinkScheme);
      expect(link.host, isEmpty);
      expect(link.path, '/albums/1');
    });

    test('both forms resolve to the same in-app location', () {
      const path = '/albums/1';
      expect(AppConfig.appLink(path).path, AppConfig.customLink(path).path);
    });
  });
}
