import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/system/about_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  group('AboutPage — loaded', () {
    testWidgets('shows the app identity', (tester) async {
      await pumpInScope(tester, const AboutPage());
      expect(find.text(AppConfig.appName), findsOneWidget);
      expect(find.text(AppConfig.appDescription), findsOneWidget);
      expect(find.text(l10n.aboutTitle), findsOneWidget);
    });

    testWidgets('shows every build metadata row', (tester) async {
      await pumpInScope(tester, const AboutPage());
      expect(find.text(testAppInfo.version), findsOneWidget);
      expect(find.text(testAppInfo.buildNumber), findsOneWidget);
      expect(find.text(testAppInfo.gitCommit), findsOneWidget);
      expect(find.text(testAppInfo.flutterVersion), findsOneWidget);
      expect(find.text(testAppInfo.dartVersion), findsOneWidget);
      expect(find.text(l10n.aboutPlatformValue), findsOneWidget);
    });

    testWidgets('asks the repository for app info exactly once', (
      tester,
    ) async {
      final scope = await pumpInScope(tester, const AboutPage());
      expect(scope.appInfoRepository.callCount, 1);
    });
  });

  group('AboutPage — failure', () {
    testWidgets('shows the error view when app info cannot be read', (
      tester,
    ) async {
      final scope = TestScope(
        appInfoRepository: FakeAppInfoRepository(failure: 'no platform'),
      );
      await pumpInScope(tester, const AboutPage(), scope: scope);
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text(l10n.commonError), findsOneWidget);
    });

    testWidgets('retry re-runs the use case', (tester) async {
      final scope = TestScope(
        appInfoRepository: FakeAppInfoRepository(failure: 'no platform'),
      );
      await pumpInScope(tester, const AboutPage(), scope: scope);
      expect(scope.appInfoRepository.callCount, 1);

      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(scope.appInfoRepository.callCount, 2);
    });
  });

  group('AboutPage — debug unlock', () {
    /// Taps the version row [times] times.
    Future<void> tapVersion(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.text(testAppInfo.version));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('seven taps turn debug mode on when it is off', (tester) async {
      final scope = TestScope(
        debugSettingsRepository: FakeDebugSettingsRepository(debugMode: false),
      );
      await pumpInScope(tester, const AboutPage(), scope: scope);

      await tapVersion(tester, 7);

      expect(scope.debugSettingsRepository.savedDebugModes, equals([true]));
      expect(find.text(l10n.aboutDebugUnlocked), findsOneWidget);
    });

    testWidgets('six taps are not enough', (tester) async {
      final scope = TestScope(
        debugSettingsRepository: FakeDebugSettingsRepository(debugMode: false),
      );
      await pumpInScope(tester, const AboutPage(), scope: scope);

      await tapVersion(tester, 6);

      expect(scope.debugSettingsRepository.savedDebugModes, isEmpty);
      expect(find.text(l10n.aboutDebugUnlocked), findsNothing);
    });

    testWidgets('tapping does nothing while debug mode is already on', (
      tester,
    ) async {
      final scope = await pumpInScope(tester, const AboutPage());
      await tapVersion(tester, 10);
      expect(scope.debugSettingsRepository.savedDebugModes, isEmpty);
      expect(find.text(l10n.aboutDebugUnlocked), findsNothing);
    });
  });
}
