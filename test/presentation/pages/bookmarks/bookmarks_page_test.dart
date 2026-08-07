import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  group('BookmarksPage — states', () {
    testWidgets('shows the empty state when nothing is stored', (tester) async {
      await pumpInScope(tester, const BookmarksPage());

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.textContaining(l10n.bookmarksEmpty), findsOneWidget);
    });

    testWidgets('lists what the repository holds, newest first', (
      tester,
    ) async {
      final scope = TestScope(
        bookmarkRepository: FakeBookmarkRepository(<Bookmark>[
          testBookmark(id: 1, title: 'Older'),
          testBookmark(id: 2, title: 'Newer'),
        ]),
      );
      await pumpInScope(tester, const BookmarksPage(), scope: scope);

      expect(find.byType(AppListCard), findsNWidgets(2));
      final titles = tester
          .widgetList<AppListCard>(find.byType(AppListCard))
          .map((card) => card.title)
          .toList();
      expect(titles, equals(<String>['Newer', 'Older']));
    });

    testWidgets('shows the URL under each title', (tester) async {
      final scope = TestScope(
        bookmarkRepository: FakeBookmarkRepository(<Bookmark>[
          testBookmark(url: 'https://dart.dev'),
        ]),
      );
      await pumpInScope(tester, const BookmarksPage(), scope: scope);
      expect(find.text('https://dart.dev'), findsOneWidget);
    });

    testWidgets('shows an error state, with the domain message, on failure', (
      tester,
    ) async {
      final repository = FakeBookmarkRepository()
        ..failure = const InfrastructureError('storage unavailable');
      final scope = TestScope(bookmarkRepository: repository);
      await pumpInScope(tester, const BookmarksPage(), scope: scope);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('storage unavailable'), findsOneWidget);
    });

    testWidgets('retry re-reads, and recovers once storage comes back', (
      tester,
    ) async {
      final repository = FakeBookmarkRepository()
        ..failure = const InfrastructureError('storage unavailable');
      final scope = TestScope(bookmarkRepository: repository);
      await pumpInScope(tester, const BookmarksPage(), scope: scope);
      expect(find.byType(AppErrorView), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsNothing);
      expect(find.byType(AppEmptyView), findsOneWidget);
    });
  });

  group('BookmarksPage — adding', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    Future<void> fillForm(
      WidgetTester tester, {
      required String title,
      required String url,
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), title);
      await tester.enterText(fields.at(1), url);
      await tester.pumpAndSettle();
    }

    testWidgets('stores a valid bookmark and reports it', (tester) async {
      final scope = await pumpInScope(tester, const BookmarksPage());

      await openForm(tester);
      await fillForm(tester, title: 'Dart', url: 'https://dart.dev');
      await tester.tap(find.text(l10n.bookmarksSave));
      await tester.pumpAndSettle();

      expect(scope.bookmarkRepository.added, hasLength(1));
      expect(scope.bookmarkRepository.added.single.title, 'Dart');
      expect(find.text(l10n.bookmarksSaved), findsOneWidget);
      expect(find.byType(AppListCard), findsOneWidget);
    });

    testWidgets('keeps the dialog open and explains a rejected URL', (
      tester,
    ) async {
      final scope = await pumpInScope(tester, const BookmarksPage());

      await openForm(tester);
      await fillForm(tester, title: 'Bad', url: 'not-a-url');
      await tester.tap(find.text(l10n.bookmarksSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookmarksInvalidInput), findsOneWidget);
      expect(scope.bookmarkRepository.added, isEmpty);
    });

    testWidgets('rejects a blank title the same way', (tester) async {
      final scope = await pumpInScope(tester, const BookmarksPage());

      await openForm(tester);
      await fillForm(tester, title: '  ', url: 'https://dart.dev');
      await tester.tap(find.text(l10n.bookmarksSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookmarksInvalidInput), findsOneWidget);
      expect(scope.bookmarkRepository.added, isEmpty);
    });

    testWidgets('does not claim a save when storage rejects the write', (
      tester,
    ) async {
      final repository = FakeBookmarkRepository();
      final scope = TestScope(bookmarkRepository: repository);
      await pumpInScope(tester, const BookmarksPage(), scope: scope);

      await openForm(tester);
      await fillForm(tester, title: 'Dart', url: 'https://dart.dev');
      repository.failure = const InfrastructureError('storage unavailable');
      await tester.tap(find.text(l10n.bookmarksSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookmarksSaved), findsNothing);
      // The list itself reports what went wrong instead.
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('storage unavailable'), findsOneWidget);
    });

    testWidgets('cancelling stores nothing', (tester) async {
      final scope = await pumpInScope(tester, const BookmarksPage());

      await openForm(tester);
      await fillForm(tester, title: 'Dart', url: 'https://dart.dev');
      await tester.tap(find.text(l10n.bookmarksCancel));
      await tester.pumpAndSettle();

      expect(scope.bookmarkRepository.added, isEmpty);
      expect(find.byType(AppEmptyView), findsOneWidget);
    });

    testWidgets('the empty state offers the same add action', (tester) async {
      await pumpInScope(tester, const BookmarksPage());

      await tester.tap(find.text(l10n.bookmarksAdd));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookmarksAddTitle), findsOneWidget);
    });
  });

  group('BookmarksPage — navigation', () {
    testWidgets('tapping a bookmark navigates to its detail location', (
      tester,
    ) async {
      final scope = TestScope(
        bookmarkRepository: FakeBookmarkRepository(<Bookmark>[
          testBookmark(id: 42),
        ]),
      );
      await pumpInScope(tester, const BookmarksPage(), scope: scope);

      await tester.tap(find.byType(AppListCard));
      await tester.pumpAndSettle();

      expect(scope.location, '/bookmarks/42');
    });
  });
}
