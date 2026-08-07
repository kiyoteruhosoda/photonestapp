import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_ja.dart';
import 'package:flutterbase/presentation/pages/system/deep_link_page.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  group('DeepLinkPage', () {
    testWidgets('echoes the URI it was opened with', (tester) async {
      await pumpInScope(
        tester,
        DeepLinkPage(uri: Uri.parse('/link?ref=email')),
      );
      expect(find.text('/link?ref=email'), findsOneWidget);
    });

    testWidgets('lists the query parameters', (tester) async {
      await pumpInScope(
        tester,
        DeepLinkPage(uri: Uri.parse('/link?ref=email&campaign=launch')),
      );

      expect(find.text('ref = email'), findsOneWidget);
      expect(find.text('campaign = launch'), findsOneWidget);
      expect(find.text(l10n.deepLinkNoParameters), findsNothing);
    });

    testWidgets('says so when there are no query parameters', (tester) async {
      await pumpInScope(tester, DeepLinkPage(uri: Uri.parse('/link')));
      expect(find.text(l10n.deepLinkNoParameters), findsOneWidget);
    });

    testWidgets('shows both the verified and the custom-scheme link', (
      tester,
    ) async {
      await pumpInScope(tester, DeepLinkPage(uri: Uri.parse('/link')));

      expect(find.text('${AppConfig.appLink('/link')}'), findsOneWidget);
      expect(find.text('${AppConfig.customLink('/link')}'), findsOneWidget);
    });

    testWidgets('shows an adb command that fires the same intent', (
      tester,
    ) async {
      await pumpInScope(tester, DeepLinkPage(uri: Uri.parse('/link')));

      expect(find.textContaining('adb shell am start'), findsOneWidget);
      expect(
        find.textContaining('android.intent.category.BROWSABLE'),
        findsOneWidget,
      );
    });

    testWidgets('copies a link to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<Object?, Object?>;
            copied = data['text'] as String?;
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

      await pumpInScope(tester, DeepLinkPage(uri: Uri.parse('/link')));
      await tester.tap(find.byIcon(Icons.copy_outlined).first);
      await tester.pumpAndSettle();

      expect(copied, '${AppConfig.appLink('/link')}');
      expect(find.text(l10n.deepLinkCopied), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pumpInScope(
        tester,
        DeepLinkPage(uri: Uri.parse('/link')),
        locale: const Locale('ja'),
      );
      expect(
        find.text(const AppLocalizationsJa().deepLinkTitle),
        findsOneWidget,
      );
    });
  });
}
