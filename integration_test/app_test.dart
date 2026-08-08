import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_widget.dart';
import 'package:flutterbase/app/di/provider_overrides.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/albums/albums_tab.dart';
import 'package:flutterbase/presentation/pages/auth/login_page.dart';
import 'package:flutterbase/presentation/pages/media/media_tab.dart';
import 'package:flutterbase/presentation/pages/system/deep_link_page.dart';
import 'package:integration_test/integration_test.dart';

const l10n = AppLocalizationsEn();

/// A session shaped like a real login, so the auth guard lets the run
/// through. No server is contacted: screens that fetch remote data render
/// their error states, which is fine — these tests exercise the app shell,
/// navigation, and the on-device stores, not the PhotoNest API.
final AuthSession integrationSession = AuthSession(
  accessToken: 'integration-access-token',
  refreshToken: 'integration-refresh-token',
  email: 'integration@example.com',
  scopes: const ['gui:view', 'album:view', 'media:view'],
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupServiceLocator();
  });

  /// The same tree `main()` runs, including the Riverpod scope the composition
  /// root installs.
  Widget app() => ProviderScope(
    overrides: buildProviderOverrides(),
    child: const AppWidget(),
  );

  group('App integration tests', () {
    testWidgets('a cold start without a session lands on the login screen', (
      tester,
    ) async {
      // The keystore persists across runs on a real device — start clean.
      await sl<SessionRepository>().clear();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a stored session skips the login screen', (tester) async {
      await sl<SessionRepository>().save(integrationSession);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('the settings tab renders its sections', (tester) async {
      await sl<SessionRepository>().save(integrationSession);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsTheme), findsAtLeast(1));
      expect(find.text(integrationSession.email), findsOneWidget);
    });

    testWidgets('the media tabs render against the real dependency graph', (
      tester,
    ) async {
      await sl<SessionRepository>().save(integrationSession);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // The home tab is the library timeline. No PhotoNest server is
      // reachable in this run, so the tab settles into its error state —
      // reaching it still means the router resolved, the DI graph produced
      // the use case, and the API client answered with a typed failure
      // instead of crashing.
      expect(find.byType(MediaTab), findsOneWidget);

      // The same for the album list, one tab over.
      await tester.tap(find.byIcon(Icons.photo_album_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumsTab), findsOneWidget);
    });

    testWidgets('the drawer reaches the deep-link diagnostics screen', (
      tester,
    ) async {
      await sl<SessionRepository>().save(integrationSession);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.drawerDeepLink).last);
      await tester.pumpAndSettle();

      // Reaching the rendered screen means the drawer, the route table, and
      // the real router agree — the whole navigation stack.
      expect(find.byType(DeepLinkPage), findsOneWidget);
    });
  });
}
