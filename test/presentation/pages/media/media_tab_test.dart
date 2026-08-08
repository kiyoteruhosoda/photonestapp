import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/media/media_tab.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  group('MediaTab', () {
    testWidgets('an empty library says so', (tester) async {
      await pumpInScope(tester, const Scaffold(body: MediaTab()));
      await tester.pumpAndSettle();

      expect(find.text(l10n.photosEmpty), findsOneWidget);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository()
          ..failure = const NetworkUnreachableError('offline'),
      );
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      expect(find.text(l10n.commonErrorNetwork), findsOneWidget);
    });

    testWidgets('media is grouped under the day it was captured', (
      tester,
    ) async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [
            testMediaItem(id: 1, shotAt: DateTime.utc(2026, 8, 5, 9)),
            testMediaItem(id: 2, shotAt: DateTime.utc(2026, 8, 5, 8)),
            testMediaItem(id: 3, shotAt: DateTime.utc(2026, 8, 4, 8)),
          ],
        ),
      );
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      // Two capture days, so two section headers and three tiles.
      expect(find.byType(MediaTile), findsNWidgets(3));
      expect(find.textContaining('August'), findsNWidgets(2));
    });

    testWidgets('media the server has no capture instant for is its own '
        'section', (tester) async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [
            testMediaItem(id: 1, shotAt: DateTime.utc(2026, 8, 5, 9)),
            testMediaItemWithoutShotAt(id: 2),
          ],
        ),
      );
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      expect(find.text(l10n.photosUndatedSection), findsOneWidget);
    });
  });

  group('groupMediaByCaptureDay', () {
    test('consecutive items of the same local day share a section', () {
      final groups = groupMediaByCaptureDay([
        testMediaItem(id: 1, shotAt: DateTime.utc(2026, 8, 5, 9)),
        testMediaItem(id: 2, shotAt: DateTime.utc(2026, 8, 5, 10)),
        testMediaItem(id: 3, shotAt: DateTime.utc(2026, 8, 4, 10)),
      ]);

      expect(groups.map((group) => group.media.length), [2, 1]);
    });

    test('the day is the local one, not the UTC one', () {
      final shotAt = DateTime.utc(2026, 8, 5, 23, 30);
      final local = shotAt.toLocal();

      final groups = groupMediaByCaptureDay([
        testMediaItem(id: 1, shotAt: shotAt),
      ]);

      expect(groups.single.day, DateTime(local.year, local.month, local.day));
    });

    test('media without a capture instant lands in its own section', () {
      final groups = groupMediaByCaptureDay([
        testMediaItem(id: 1, shotAt: DateTime.utc(2026, 8, 5, 9)),
        testMediaItemWithoutShotAt(id: 2),
        testMediaItem(id: 3, shotAt: DateTime.utc(2026, 8, 5, 8)),
      ]);

      expect(groups.map((group) => group.day), [isNotNull, isNull, isNotNull]);
    });

    test('an empty library has no sections', () {
      expect(groupMediaByCaptureDay(const []), isEmpty);
    });
  });
}
