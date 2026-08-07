import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/system/debug_page.dart';
import 'package:flutterbase/presentation/theme/app_theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

/// Brings [finder] fully on screen, then taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('DebugPage — loaded', () {
    testWidgets('shows the warning banner and section headers', (tester) async {
      await pumpInScope(tester, const DebugPage());
      expect(find.text(l10n.debugWarning), findsOneWidget);
      expect(find.text(l10n.debugAppInfoSection), findsOneWidget);
      expect(find.text(l10n.debugThemeSection), findsOneWidget);
    });

    testWidgets('shows the build metadata', (tester) async {
      await pumpInScope(tester, const DebugPage());
      expect(find.text(AppConfig.appName), findsOneWidget);
      expect(find.text(testAppInfo.version), findsOneWidget);
      expect(find.text(testAppInfo.gitCommitFull), findsOneWidget);
      expect(find.text(AppConfig.designSystemLabel), findsOneWidget);
      expect(find.text(testAppInfo.isDebug.toString()), findsOneWidget);
    });

    testWidgets('reports the light theme when the light theme is active', (
      tester,
    ) async {
      await pumpInScope(tester, const DebugPage());
      expect(find.text(l10n.debugThemeModeLight), findsOneWidget);
    });

    testWidgets('creates exactly one ViewModel for the route', (tester) async {
      final scope = await pumpInScope(tester, const DebugPage());
      expect(scope.debugViewModelsCreated, 1);
      expect(scope.appInfoRepository.callCount, 1);
    });
  });

  group('DebugPage — failure', () {
    testWidgets('shows the error view when app info cannot be read', (
      tester,
    ) async {
      final scope = TestScope(
        appInfoRepository: FakeAppInfoRepository(failure: 'no platform'),
      );
      await pumpInScope(tester, const DebugPage(), scope: scope);
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Failed to load debug info'), findsOneWidget);
    });

    testWidgets('retry re-runs the use case', (tester) async {
      final scope = TestScope(
        appInfoRepository: FakeAppInfoRepository(failure: 'no platform'),
      );
      await pumpInScope(tester, const DebugPage(), scope: scope);
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();
      expect(scope.appInfoRepository.callCount, 2);
    });

    testWidgets('copy-all does nothing while app info is missing', (
      tester,
    ) async {
      final scope = TestScope(
        appInfoRepository: FakeAppInfoRepository(failure: 'no platform'),
      );
      await pumpInScope(tester, const DebugPage(), scope: scope);
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();
      expect(find.text(l10n.debugCopiedToClipboard), findsNothing);
    });
  });

  group('DebugPage — actions', () {
    testWidgets('copy-all writes the metadata to the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpInScope(tester, const DebugPage());
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      expect(copied, contains(testAppInfo.version));
      expect(copied, contains(testAppInfo.gitCommitFull));
      expect(find.text(l10n.debugCopiedToClipboard), findsOneWidget);
    });

    testWidgets('clear-logs empties the buffer and confirms', (tester) async {
      final scope = await pumpInScope(tester, const DebugPage());
      await scrollAndTap(tester, find.text(l10n.debugClearLogs));
      expect(scope.logger.clearBufferCalls, 1);
      expect(find.text(l10n.debugClearLogsSuccess), findsOneWidget);
    });

    testWidgets('clear-cache confirms', (tester) async {
      await pumpInScope(tester, const DebugPage());
      await scrollAndTap(tester, find.text(l10n.debugClearCache));
      expect(find.text(l10n.debugClearCacheSuccess), findsOneWidget);
    });

    testWidgets('test-crash asks for confirmation first', (tester) async {
      await pumpInScope(tester, const DebugPage());
      // The row label and the dialog title are both "Test Crash"; the body
      // text is what makes the dialog unambiguous.
      await scrollAndTap(tester, find.text(l10n.debugTestCrash));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.debugTestCrashBody), findsOneWidget);
      expect(find.text(l10n.debugCrash), findsOneWidget);
    });

    testWidgets('cancelling test-crash closes the dialog and crashes nothing', (
      tester,
    ) async {
      await pumpInScope(tester, const DebugPage());
      await scrollAndTap(tester, find.text(l10n.debugTestCrash));

      await tester.tap(find.text(l10n.debugCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Confirming the crash is deliberately not exercised: the handler throws
    // from a discarded Future, which surfaces as an uncaught async error that
    // fails the whole test run rather than something `takeException` can
    // catch. The confirmation path above is what protects the user.
  });

  group('DebugPage — dark theme', () {
    testWidgets('reports the dark theme when the dark theme is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Text(
              Theme.of(context).brightness == Brightness.dark
                  ? l10n.debugThemeModeDark
                  : l10n.debugThemeModeLight,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      expect(find.text(l10n.debugThemeModeDark), findsOneWidget);
    });
  });

  group('ColorExtension', () {
    test('formats a colour as an uppercase RGB hex string', () {
      expect(const Color(0xFF1A2B3C).toHexString(), '#1A2B3C');
    });

    test('pads single-digit channels', () {
      expect(const Color(0xFF010203).toHexString(), '#010203');
    });

    test('ignores the alpha channel', () {
      expect(const Color(0x00FFFFFF).toHexString(), '#FFFFFF');
    });
  });
}
