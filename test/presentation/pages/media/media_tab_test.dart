import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/media/media_tab.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';
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

    testWidgets('an empty library can be reloaded from the empty state', (
      tester,
    ) async {
      final repository = FakeMediaLibraryRepository();
      final scope = TestScope(mediaLibraryRepository: repository);
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      // The first photo arrives from somewhere else — the upload tab, or
      // another client — while the empty state is on screen.
      repository.media = [testMediaItem(id: 1)];
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(find.byType(MediaTile), findsOneWidget);
    });

    testWidgets('the next page waits for the reader instead of downloading '
        'the whole library at once', (tester) async {
      // A phone-sized surface, so the first page does not fit on screen —
      // the default test surface is tall enough to show all of it, which
      // would legitimately reach the load-more cell.
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeMediaLibraryRepository(
        media: [for (var i = 1; i <= 250; i++) testMediaItem(id: i)],
      );
      final scope = TestScope(mediaLibraryRepository: repository);
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      // The load-more cell sits far below the fold, so only the first page
      // has been asked for. Building it eagerly would chain straight through
      // the whole library at startup.
      expect(repository.requestedPages, [(1, libraryMediaPageSize)]);
    });

    testWidgets('scrolling to the end pages the next window in', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeMediaLibraryRepository(
        media: [for (var i = 1; i <= 250; i++) testMediaItem(id: i)],
      );
      final scope = TestScope(mediaLibraryRepository: repository);
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      // Scroll towards the end. The load-more cell is built — and the next
      // page requested — as soon as it comes within the grid's build range.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 60 && repository.requestedPages.length < 2; i++) {
        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(repository.requestedPages, [
        (1, libraryMediaPageSize),
        (2, libraryMediaPageSize),
      ]);
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
