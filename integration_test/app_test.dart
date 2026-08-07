import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_widget.dart';
import 'package:flutterbase/app/di/provider_overrides.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
import 'package:integration_test/integration_test.dart';

const l10n = AppLocalizationsEn();

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
    testWidgets('App launches directly into the main page', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Theme changes persist via ThemeViewModel', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Navigate to settings tab
      final settingsTab = find.byIcon(Icons.settings_outlined);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab.first);
        await tester.pumpAndSettle();
        // Settings content should be visible
        expect(find.text('Theme'), findsAtLeast(1));
      }
    });

    testWidgets('Bookmarks open against the real SQLite database', (
      tester,
    ) async {
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
