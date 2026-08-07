import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_router.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_detail_page.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
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
  Future<TestScope> openAt(WidgetTester tester, String location) async {
    tester.view
      ..physicalSize = tallSurface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scope = TestScope();
    final router = AppRouter.create(
      logger: scope.logger,
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(scope.wrapRouter(router));
    await tester.pumpAndSettle();
    return scope;
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

    testWidgets('/bookmarks opens the bookmarks list', (tester) async {
      await openAt(tester, AppRoutes.bookmarks);
      expect(find.byType(BookmarksPage), findsOneWidget);
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
    testWidgets('a bookmark link opens the detail screen for that id', (
      tester,
    ) async {
      final scope = TestScope(
        bookmarkRepository: FakeBookmarkRepository(<Bookmark>[
          testBookmark(id: 7, title: 'Deep linked'),
        ]),
      );
      tester.view
        ..physicalSize = tallSurface
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = AppRouter.create(
        logger: scope.logger,
        initialLocation: '/bookmarks/7',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(scope.wrapRouter(router));
      await tester.pumpAndSettle();

      expect(find.byType(BookmarkDetailPage), findsOneWidget);
      expect(find.text('Deep linked'), findsOneWidget);
    });

    testWidgets('a link to a bookmark this device does not have is not an '
        'error', (tester) async {
      await openAt(tester, '/bookmarks/999');
      expect(find.byType(BookmarkDetailPage), findsOneWidget);
      expect(find.textContaining(l10n.bookmarkNotFound), findsOneWidget);
    });

    testWidgets('a non-numeric id renders the not-found state', (tester) async {
      await openAt(tester, '/bookmarks/not-an-id');
      expect(find.byType(BookmarkDetailPage), findsOneWidget);
      expect(find.textContaining(l10n.bookmarkNotFound), findsOneWidget);
    });

    testWidgets('the path of an App Link resolves to the same route', (
      tester,
    ) async {
      // What Android hands over is the URL's path, not the whole URL.
      final link = AppConfig.appLink('/bookmarks/7');
      await openAt(tester, link.path);
      expect(find.byType(BookmarkDetailPage), findsOneWidget);
    });

    testWidgets('the custom-scheme form carries the same path', (tester) async {
      final link = AppConfig.customLink('/bookmarks/7');
      expect(link.path, '/bookmarks/7');

      await openAt(tester, link.path);
      expect(find.byType(BookmarkDetailPage), findsOneWidget);
    });

    testWidgets('query parameters survive to the screen', (tester) async {
      await openAt(tester, '/link?ref=email&campaign=launch');

      expect(find.byType(DeepLinkPage), findsOneWidget);
      expect(find.textContaining('ref = email'), findsOneWidget);
      expect(find.textContaining('campaign = launch'), findsOneWidget);
    });

    testWidgets('every resolved location is logged', (tester) async {
      final scope = await openAt(tester, '/bookmarks/7');
      expect(
        scope.logger.messagesAt(LogLevel.debug),
        contains(contains('[Router] → /bookmarks/7')),
      );
    });
  });
}
