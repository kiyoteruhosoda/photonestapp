import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/system/not_found_page.dart';

import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  group('NotFoundPage', () {
    testWidgets('names the location that failed to match', (tester) async {
      await pumpInScope(
        tester,
        NotFoundPage(uri: Uri.parse('/bookmarks/nope?from=email')),
      );

      expect(find.text(l10n.commonNotFound), findsOneWidget);
      expect(find.text('/bookmarks/nope?from=email'), findsOneWidget);
    });

    testWidgets('offers a way back to Home', (tester) async {
      final scope = await pumpInScope(
        tester,
        NotFoundPage(uri: Uri.parse('/nope')),
      );

      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();

      expect(scope.location, '/');
    });
  });
}
