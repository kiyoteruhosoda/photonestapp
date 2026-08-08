import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_router.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/albums/album_detail_page.dart';
import 'package:flutterbase/presentation/pages/auth/login_page.dart';
import 'package:flutterbase/presentation/pages/main_page.dart';
import 'package:flutterbase/presentation/pages/system/about_page.dart';
import 'package:flutterbase/presentation/pages/system/deep_link_page.dart';
import 'package:flutterbase/presentation/pages/system/not_found_page.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  /// Starts the app's real router at [location].
  ///
  /// This is the closest a widget test gets to a deep link: Android hands
  /// Flutter the *path* of the tapped URL, and the framework starts the
  /// Router there — which is exactly what `initialLocation` does here.
  Future<TestScope> openAt(
    WidgetTester tester,
    String location, {
    TestScope? scope,
  }) async {
    tester.view
      ..physicalSize = tallSurface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final resolved = scope ?? TestScope();
    final router = AppRouter.create(
      logger: resolved.logger,
      refreshListenable: resolved.routerRefresh(),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(resolved.wrapRouter(router));
    await tester.pumpAndSettle();
    return resolved;
  }

  group('AppRouter — in-app locations', () {
    testWidgets('/ opens the main page', (tester) async {
      await openAt(tester, AppRoutes.main);
      expect(find.byType(MainPage), findsOneWidget);
    });

    testWidgets('/about opens the about page', (tester) async {
      await openAt(tester, AppRoutes.about);
      expect(find.byType(AboutPage), findsOneWidget);
    });

    testWidgets('an unknown location shows the not-found page', (tester) async {
      await openAt(tester, '/no-such-screen');
      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(find.text('/no-such-screen'), findsOneWidget);
    });

    testWidgets('the not-found page offers a way back to Home', (tester) async {
      await openAt(tester, '/no-such-screen');
      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();
      expect(find.byType(MainPage), findsOneWidget);
    });

    testWidgets('every screen keeps Home beneath it, so back works', (
      tester,
    ) async {
      await openAt(tester, AppRoutes.about);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MainPage), findsOneWidget);
    });
  });

  group('AppRouter — deep links', () {
    /// A scope whose server holds one album — id 7 — with one media item.
    TestScope scopeWithAlbum7() => TestScope(
      albumRepository: FakeAlbumRepository(
        details: {
          AlbumId(7): AlbumDetail(
            album: testAlbum(id: 7, title: 'Deep linked', coverMediaId: null),
            media: [testAlbumMediaItem()],
          ),
        },
      ),
    );

    testWidgets('an album link opens the detail screen for that id', (
      tester,
    ) async {
      await openAt(tester, '/albums/7', scope: scopeWithAlbum7());
      expect(find.byType(AlbumDetailPage), findsOneWidget);
      expect(find.text('Deep linked'), findsOneWidget);
    });

    testWidgets('a link to an album the server does not have is not an '
        'error', (tester) async {
      await openAt(tester, '/albums/999');
      expect(find.byType(AlbumDetailPage), findsOneWidget);
      expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
    });

    testWidgets('a non-numeric id renders the not-found state', (tester) async {
      await openAt(tester, '/albums/not-an-id');
      expect(find.byType(AlbumDetailPage), findsOneWidget);
      expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
    });

    testWidgets('the path of an App Link resolves to the same route', (
      tester,
    ) async {
      // What Android hands over is the URL's path, not the whole URL.
      final link = AppConfig.appLink('/albums/7');
      await openAt(tester, link.path, scope: scopeWithAlbum7());
      expect(find.byType(AlbumDetailPage), findsOneWidget);
    });

    testWidgets('the custom-scheme form carries the same path', (tester) async {
      final link = AppConfig.customLink('/albums/7');
      expect(link.path, '/albums/7');

      await openAt(tester, link.path, scope: scopeWithAlbum7());
      expect(find.byType(AlbumDetailPage), findsOneWidget);
    });

    testWidgets('query parameters survive to the screen', (tester) async {
      await openAt(tester, '/link?ref=email&campaign=launch');

      expect(find.byType(DeepLinkPage), findsOneWidget);
      expect(find.textContaining('ref = email'), findsOneWidget);
      expect(find.textContaining('campaign = launch'), findsOneWidget);
    });

    testWidgets('every resolved location is logged', (tester) async {
      final scope = await openAt(tester, '/albums/7');
      expect(
        scope.logger.messagesAt(LogLevel.debug),
        contains(contains('[Router] → /albums/7')),
      );
    });
  });

  group('AppRouter — authentication guard', () {
    TestScope signedOut() =>
        TestScope(sessionRepository: FakeSessionRepository());

    testWidgets('a signed-out start lands on the login page', (tester) async {
      await openAt(tester, AppRoutes.main, scope: signedOut());
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('a deep link while signed out is redirected to login', (
      tester,
    ) async {
      await openAt(tester, '/albums/7', scope: signedOut());
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('a signed-in user asking for /login gets the main page', (
      tester,
    ) async {
      await openAt(tester, AppRoutes.login);
      expect(find.byType(MainPage), findsOneWidget);
    });

    testWidgets('logging in navigates from the login page to the main page', (
      tester,
    ) async {
      final scope = signedOut();
      await openAt(tester, AppRoutes.main, scope: scope);
      expect(find.byType(LoginPage), findsOneWidget);

      final loggedIn = await scope.session.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      );
      expect(loggedIn, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(MainPage), findsOneWidget);
    });

    testWidgets('logging out navigates back to the login page', (tester) async {
      final scope = await openAt(tester, AppRoutes.main);
      expect(find.byType(MainPage), findsOneWidget);

      await scope.session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
