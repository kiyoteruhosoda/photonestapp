import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_widget.dart';
import 'package:flutterbase/app/di/provider_overrides.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/auth/login_page.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
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

    testWidgets('bookmarks open against the real SQLite database', (
      tester,
    ) async {
      await sl<SessionRepository>().save(integrationSession);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.drawerBookmarks).last);
      await tester.pumpAndSettle();

      // Reaching a rendered list (empty or not) means the database opened,
      // the repository answered, and the router resolved — the whole stack.
      expect(find.byType(BookmarksPage), findsOneWidget);
    });
  });
}
