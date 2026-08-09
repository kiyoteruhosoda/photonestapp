import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/pages/media/media_search_bar.dart';
import 'package:photonest/presentation/pages/media/media_tab.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

/// The narrowing the timeline reads under.
MediaLibraryQuery lastQuery(FakeMediaLibraryRepository repository) {
  expect(repository.requestedQueries, isNotEmpty);
  return repository.requestedQueries.last;
}

/// Waits out the typing pause so the search actually reaches the server.
Future<void> settleDebounce(WidgetTester tester) async {
  await tester.pump(mediaSearchDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  group('MediaSearchBar', () {
    testWidgets('the plain timeline asks for no narrowing', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      expect(lastQuery(repository).isUnfiltered, isTrue);
    });

    testWidgets('typing re-reads the library with the text', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beach');
      // Before the pause elapses nothing has been sent.
      expect(lastQuery(repository).searchText, isNull);

      await settleDebounce(tester);

      expect(lastQuery(repository).searchText, 'beach');
      // A narrowed read starts from the first window, never from a cursor
      // taken under the previous narrowing.
      expect(repository.requestedPages.last.$1, isNull);
    });

    testWidgets('one request per pause, not per keystroke', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();
      final before = repository.requestedPages.length;

      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'be');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'bea');
      await settleDebounce(tester);

      expect(repository.requestedPages.length - before, 1);
      expect(lastQuery(repository).searchText, 'bea');
    });

    testWidgets('the kind chips narrow to photos or videos', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.searchFilterVideos));
      await tester.pumpAndSettle();

      expect(lastQuery(repository).kind, MediaKindFilter.video);

      await tester.tap(find.text(l10n.searchFilterAll));
      await tester.pumpAndSettle();

      expect(lastQuery(repository).kind, MediaKindFilter.any);
    });

    testWidgets('the favourites chip narrows to favourites', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.searchFilterFavorites));
      await tester.pumpAndSettle();

      expect(lastQuery(repository).favoritesOnly, isTrue);
    });

    testWidgets('a narrowing that matches nothing offers a way back', (
      tester,
    ) async {
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
        // The server answers the narrowing; nothing matches.
      )..matches = (item, query) => query.isUnfiltered;
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await settleDebounce(tester);

      // "No results" rather than "the library is empty" — the two have
      // different fixes, and the fix here is to loosen the narrowing.
      expect(find.text(l10n.searchNoResults), findsOneWidget);
      expect(find.text(l10n.photosEmpty), findsNothing);

      await tester.tap(find.text(l10n.searchClearFilters));
      await tester.pumpAndSettle();

      expect(lastQuery(repository).isUnfiltered, isTrue);
      expect(find.byType(MediaTile), findsOneWidget);
    });

    testWidgets('an empty library still says the library is empty', (
      tester,
    ) async {
      final repository = FakeMediaLibraryRepository();
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.photosEmpty), findsOneWidget);
      expect(find.text(l10n.searchNoResults), findsNothing);
    });

    testWidgets('the search field stays put while the read is in flight', (
      tester,
    ) async {
      // Taking the field away during loading would leave the reader unable
      // to correct a narrowing that returns nothing.
      final repository = FakeMediaLibraryRepository(
        media: [testMediaItem(id: 1)],
      );
      await pumpInScope(
        tester,
        const Scaffold(body: MediaTab()),
        scope: TestScope(mediaLibraryRepository: repository),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the next window carries the same narrowing', (tester) async {
      final repository = FakeMediaLibraryRepository(
        media: [for (var i = 1; i <= 250; i++) testMediaItem(id: i)],
      );
      final scope = TestScope(mediaLibraryRepository: repository);
      await pumpInScope(tester, const Scaffold(body: MediaTab()), scope: scope);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'trip');
      await settleDebounce(tester);
      final pagesAfterSearch = repository.requestedPages.length;

      await scope.container.read(libraryMediaProvider.notifier).loadMore();
      await tester.pumpAndSettle();

      expect(repository.requestedPages.length, pagesAfterSearch + 1);
      // The cursor is followed, and the narrowing goes with it — otherwise
      // the second window would come from the unfiltered library.
      expect(repository.requestedPages.last.$1, isNotNull);
      expect(lastQuery(repository).searchText, 'trip');
    });
  });

  group('MediaLibraryQuery', () {
    test('blank text is not sent as a filter', () {
      expect(const MediaLibraryQuery(text: '   ').searchText, isNull);
      expect(const MediaLibraryQuery(text: '  x ').searchText, 'x');
    });

    test('isUnfiltered is only true when nothing is narrowed', () {
      expect(const MediaLibraryQuery().isUnfiltered, isTrue);
      expect(const MediaLibraryQuery(text: 'a').isUnfiltered, isFalse);
      expect(
        const MediaLibraryQuery(kind: MediaKindFilter.video).isUnfiltered,
        isFalse,
      );
      expect(
        const MediaLibraryQuery(favoritesOnly: true).isUnfiltered,
        isFalse,
      );
    });

    test('equality is by the fields, so a rebuild is not a change', () {
      expect(
        const MediaLibraryQuery(text: 'a', kind: MediaKindFilter.photo),
        const MediaLibraryQuery(text: 'a', kind: MediaKindFilter.photo),
      );
      expect(
        const MediaLibraryQuery(text: 'a'),
        isNot(const MediaLibraryQuery(text: 'b')),
      );
    });

    test('only photo and video reach the server as a type', () {
      expect(MediaKindFilter.any.queryValue, isNull);
      expect(MediaKindFilter.photo.queryValue, 'photo');
      expect(MediaKindFilter.video.queryValue, 'video');
    });
  });
}
