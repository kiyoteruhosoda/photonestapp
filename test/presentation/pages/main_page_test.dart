import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/app_theme_mode.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/main_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

/// Switches to the tab at [index] of the bottom navigation bar.
Future<void> selectTab(WidgetTester tester, int index) async {
  final destinations = find.byType(NavigationDestination);
  await tester.tap(destinations.at(index));
  await tester.pumpAndSettle();
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

/// Matches [text] only inside the tab body, not in the bottom navigation bar
/// or the drawer — several labels appear in more than one of those.
Finder inBody(String text) => find.descendant(
  of: find.byType(Scaffold).first,
  matching: find.descendant(
    of: find.byType(ListView).first,
    matching: find.text(text),
  ),
);

/// Matches [text] inside the open drawer. Several drawer entries share a
/// label with the bottom navigation bar.
Finder inDrawer(String text) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(text));

/// Scrolls the tab body until [finder] is on screen.
///
/// The Settings tab is taller than a test viewport, so most of its rows have
/// to be scrolled into view before they can be tapped.
Future<void> scrollToTop(WidgetTester tester) async {
  for (var attempt = 0; attempt < 15; attempt++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
  }
}

/// Scrolls the current tab from the top until [finder] has [minMatches]
/// matches, then makes the first of them fully visible.
///
/// Drags rather than using `scrollUntilVisible`: the tab body is a lazy
/// ListView, so the target does not exist until it scrolls into range, and an
/// indexed finder over a not-yet-built subtree throws instead of matching
/// nothing.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  int minMatches = 1,
}) async {
  await scrollToTop(tester);
  for (var attempt = 0; attempt < 30; attempt++) {
    if (tester.widgetList(finder).length >= minMatches) break;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
  }
  expect(
    finder,
    findsAtLeastNWidgets(minMatches),
    reason: 'never scrolled into view',
  );
}

/// Scrolls [finder] into view and taps it.
Future<void> scrollAndTapFinder(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls [text] into view, then taps it.
Future<void> scrollAndTap(WidgetTester tester, String text) =>
    scrollAndTapFinder(tester, find.text(text));

/// Reads `canPop` off MainPage's PopScope without naming its type argument.
bool canPopFromMainPage(WidgetTester tester) {
  final element = tester.element(
    find.byWidgetPredicate((w) => w is PopScope).first,
  );
  final widget = element.widget as dynamic;
  // ignore: avoid_dynamic_calls
  return widget.canPop as bool;
}

void main() {
  group('MainPage — chrome', () {
    testWidgets('opens on the Home tab', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(find.text(l10n.homeWelcomeTitle), findsOneWidget);
      expect(find.text(AppConfig.homeSubtitle), findsOneWidget);
    });

    testWidgets('shows the app name in the header', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(find.text(l10n.appName), findsAtLeastNWidgets(1));
    });

    testWidgets('offers three navigation destinations', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(find.byType(NavigationDestination), findsNWidgets(3));
    });

    testWidgets('renders a notifications action', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
    });
  });

  group('MainPage — tabs', () {
    testWidgets('Search tab shows the search field and empty state', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 1);
      // "Search" is also the navigation destination label, hence >= 1.
      expect(find.text(l10n.searchFieldLabel), findsAtLeastNWidgets(1));
      expect(find.text(l10n.searchEmptyMessage), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
    });

    testWidgets('Settings tab shows theme and language sections', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      expect(inBody(l10n.settingsTheme), findsOneWidget);
      expect(inBody(l10n.settingsLanguage), findsOneWidget);
    });

    testWidgets('returns to Home when the Home tab is selected again', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      expect(inBody(l10n.settingsTitle), findsOneWidget);
      await selectTab(tester, 0);
      expect(find.text(l10n.homeWelcomeTitle), findsOneWidget);
    });

    testWidgets('the Home tab exercises its demo components', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(find.byType(AppPrimaryButton), findsOneWidget);
      expect(find.byType(AppSecondaryButton), findsOneWidget);
      await tester.tap(find.text(l10n.homePrimaryButton));
      await tester.tap(find.text(l10n.homeSecondaryButton));
      await tester.pumpAndSettle();

      // The demo list cards sit below the fold on a test-sized viewport.
      await scrollTo(tester, find.text(l10n.homeListCardTitle));
      expect(find.byType(AppListCard), findsAtLeastNWidgets(1));
      await scrollAndTap(tester, l10n.homeListCardTitle);
    });
  });

  group('MainPage — back handling', () {
    testWidgets('a back gesture off Home returns to Home instead of popping', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      expect(inBody(l10n.settingsTitle), findsOneWidget);
      expect(canPopFromMainPage(tester), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeWelcomeTitle), findsOneWidget);
    });

    testWidgets('a back gesture on Home is allowed to pop', (tester) async {
      await pumpInScope(tester, const MainPage());
      expect(canPopFromMainPage(tester), isTrue);
    });
  });

  group('MainPage — drawer', () {
    testWidgets('lists the primary destinations and the About entry', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      expect(inDrawer(AppConfig.appTagline), findsOneWidget);
      expect(inDrawer(l10n.navHome), findsOneWidget);
      expect(inDrawer(l10n.drawerAbout), findsOneWidget);
      expect(inDrawer(l10n.drawerLicenses), findsOneWidget);
    });

    testWidgets('shows the developer entries while debug mode is on', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      expect(inDrawer(l10n.drawerLogs), findsOneWidget);
      expect(inDrawer(l10n.drawerDebug), findsOneWidget);
    });

    testWidgets('hides the developer entries while debug mode is off', (
      tester,
    ) async {
      final scope = TestScope(
        debugSettingsRepository: FakeDebugSettingsRepository(debugMode: false),
      );
      await pumpInScope(tester, const MainPage(), scope: scope);
      await openDrawer(tester);
      expect(inDrawer(l10n.drawerLogs), findsNothing);
      expect(inDrawer(l10n.drawerDebug), findsNothing);
    });

    testWidgets('selecting Search from the drawer switches tab and closes', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.navSearch));
      await tester.pumpAndSettle();
      expect(find.text(l10n.searchEmptyMessage), findsOneWidget);
    });

    testWidgets('selecting Settings from the drawer switches tab', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.navSettings));
      await tester.pumpAndSettle();
      expect(inBody(l10n.settingsTitle), findsOneWidget);
    });

    testWidgets('selecting Home from the drawer keeps Home selected', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 1);
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.navHome));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeWelcomeTitle), findsOneWidget);
    });

    testWidgets('About in the drawer navigates to /about', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerAbout));
      await tester.pumpAndSettle();
      expect(scope.location, '/about');
    });

    testWidgets('Logs in the drawer navigates to /logs', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerLogs));
      await tester.pumpAndSettle();
      expect(scope.location, '/logs');
    });

    testWidgets('Debug in the drawer navigates to /debug', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerDebug));
      await tester.pumpAndSettle();
      expect(scope.location, '/debug');
    });

    testWidgets('Bookmarks in the drawer navigates to /bookmarks', (
      tester,
    ) async {
      final scope = await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerBookmarks));
      await tester.pumpAndSettle();
      expect(scope.location, '/bookmarks');
    });

    testWidgets('Deep Links in the drawer navigates to /link', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerDeepLink));
      await tester.pumpAndSettle();
      expect(scope.location, '/link');
    });

    testWidgets('Licenses in the drawer opens the license page', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await openDrawer(tester);
      await tester.tap(inDrawer(l10n.drawerLicenses));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('MainPage — settings', () {
    testWidgets('switching theme persists the choice', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTap(tester, l10n.settingsThemeDark);

      expect(scope.themeRepository.saved, equals([AppThemeMode.dark]));
      expect(scope.themeViewModel.themeMode, ThemeMode.dark);
    });

    testWidgets('every theme option is reachable', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTap(tester, l10n.settingsThemeDark);
      await scrollAndTapFinder(
        tester,
        find.byIcon(Icons.brightness_auto_outlined),
      );
      await scrollAndTap(tester, l10n.settingsThemeLight);

      expect(
        scope.themeRepository.saved,
        equals([AppThemeMode.dark, AppThemeMode.system, AppThemeMode.light]),
      );
    });

    testWidgets('switching language persists the choice', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTap(tester, l10n.settingsLanguageJapanese);

      expect(scope.languageRepository.saved, equals([AppLanguage.japanese]));
    });

    testWidgets('every language option is reachable', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTap(tester, l10n.settingsLanguageJapanese);
      await scrollAndTap(tester, l10n.settingsLanguageEnglish);
      // "System default" is the label under both Theme and Language; the
      // leading icon is what tells the two rows apart.
      await scrollAndTapFinder(tester, find.byIcon(Icons.language_outlined));

      expect(
        scope.languageRepository.saved,
        equals([AppLanguage.japanese, AppLanguage.english, AppLanguage.system]),
      );
    });

    testWidgets('the developer section is visible while debug mode is on', (
      tester,
    ) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollTo(tester, find.text(l10n.settingsDeveloper));
      expect(find.text(l10n.settingsDeveloper), findsOneWidget);
      expect(find.text(l10n.settingsDebugMode), findsOneWidget);
      expect(find.text(l10n.settingsLogLevel), findsOneWidget);
    });

    testWidgets('turning debug mode off hides the developer section', (
      tester,
    ) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTapFinder(tester, find.byType(SwitchListTile));

      expect(scope.debugSettingsRepository.savedDebugModes, equals([false]));
      expect(find.text(l10n.settingsDeveloper), findsNothing);
      expect(find.text(l10n.settingsLogs), findsNothing);
    });

    testWidgets('choosing a log level persists it', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);

      await scrollAndTapFinder(tester, find.byType(DropdownButton<LogLevel>));
      await tester.tap(find.text(l10n.logLevelError).last);
      await tester.pumpAndSettle();

      expect(
        scope.debugSettingsRepository.savedLogLevels,
        equals([LogLevel.error]),
      );
    });

    testWidgets('the About row navigates to /about', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsAbout);
      expect(scope.location, '/about');
    });

    testWidgets('the Logs row navigates to /logs', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsLogs);
      expect(scope.location, '/logs');
    });

    testWidgets('the Debug row navigates to /debug', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsDebug);
      expect(scope.location, '/debug');
    });

    testWidgets('the Bookmarks row navigates to /bookmarks', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsBookmarks);
      expect(scope.location, '/bookmarks');
    });

    testWidgets('the Deep Links row navigates to /link', (tester) async {
      final scope = await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsDeepLink);
      expect(scope.location, '/link');
    });

    testWidgets('the Licenses row opens the license page', (tester) async {
      await pumpInScope(tester, const MainPage());
      await selectTab(tester, 2);
      await scrollAndTap(tester, l10n.settingsLicenses);
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('with debug mode off the developer rows are absent', (
      tester,
    ) async {
      final scope = TestScope(
        debugSettingsRepository: FakeDebugSettingsRepository(debugMode: false),
      );
      await pumpInScope(tester, const MainPage(), scope: scope);
      await selectTab(tester, 2);
      expect(find.text(l10n.settingsDeveloper), findsNothing);
      expect(find.text(l10n.settingsLogs), findsNothing);
      expect(find.text(l10n.settingsDebug), findsNothing);
    });
  });
}
