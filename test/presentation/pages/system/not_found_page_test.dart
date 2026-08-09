import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/pages/system/not_found_page.dart';

import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  group('NotFoundPage', () {
    testWidgets('names the location that failed to match', (tester) async {
      await pumpInScope(
        tester,
        NotFoundPage(uri: Uri.parse('/albums/nope?from=email')),
      );

      expect(find.text(l10n.commonNotFound), findsOneWidget);
      expect(find.text('/albums/nope?from=email'), findsOneWidget);
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
