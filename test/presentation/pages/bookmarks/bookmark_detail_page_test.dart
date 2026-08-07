import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_detail_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  TestScope scopeWith(List<Bookmark> stored) =>
      TestScope(bookmarkRepository: FakeBookmarkRepository(stored));

  group('BookmarkDetailPage — resolving the id', () {
    testWidgets('shows the not-found state for an unparseable id', (
      tester,
    ) async {
      // What the router passes when the path segment was not a number.
      await pumpInScope(tester, const BookmarkDetailPage(id: null));
      expect(find.textContaining(l10n.bookmarkNotFound), findsOneWidget);
    });

    testWidgets('shows the not-found state for an id nothing is stored under', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(404)),
        scope: scopeWith(<Bookmark>[]),
      );
      expect(find.textContaining(l10n.bookmarkNotFound), findsOneWidget);
    });

    testWidgets('shows an error state when storage fails', (tester) async {
      final repository = FakeBookmarkRepository()
        ..failure = const InfrastructureError('storage unavailable');
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(1)),
        scope: TestScope(bookmarkRepository: repository),
      );

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('storage unavailable'), findsOneWidget);
    });
  });

  group('BookmarkDetailPage — content', () {
    testWidgets('renders the title, URL, and the link that reopens it', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scopeWith(<Bookmark>[
          testBookmark(
            id: 7,
            title: 'Flutter',
            url: 'https://docs.flutter.dev',
          ),
        ]),
      );

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('https://docs.flutter.dev'), findsOneWidget);
      expect(find.text('${AppConfig.appLink('/bookmarks/7')}'), findsOneWidget);
    });

    testWidgets('renders the stored UTC instant in the local time zone', (
      tester,
    ) async {
      final createdAt = DateTime.utc(2026, 8, 3, 12, 30);
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scopeWith(<Bookmark>[testBookmark(id: 7, createdAt: createdAt)]),
      );

      final local = createdAt.toLocal();
      final materialL10n = MaterialLocalizations.of(
        tester.element(find.byType(BookmarkDetailPage)),
      );
      expect(
        find.textContaining(materialL10n.formatFullDate(local)),
        findsOneWidget,
      );
    });
  });

  group('BookmarkDetailPage — actions', () {
    testWidgets('opening hands the URL to the link launcher port', (
      tester,
    ) async {
      final scope = scopeWith(<Bookmark>[
        testBookmark(id: 7, url: 'https://dart.dev'),
      ]);
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scope,
      );

      await tester.tap(find.text(l10n.bookmarkOpen));
      await tester.pumpAndSettle();

      expect(
        scope.linkLauncher.opened,
        equals([Uri.parse('https://dart.dev')]),
      );
    });

    testWidgets('reports when nothing on the device can open the URL', (
      tester,
    ) async {
      final scope = TestScope(
        bookmarkRepository: FakeBookmarkRepository(<Bookmark>[
          testBookmark(id: 7),
        ]),
        linkLauncher: RecordingExternalLinkLauncher(result: false),
      );
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scope,
      );

      await tester.tap(find.text(l10n.bookmarkOpen));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bookmarkOpenFailed), findsOneWidget);
    });

    testWidgets('deleting asks first, and cancelling keeps the bookmark', (
      tester,
    ) async {
      final scope = scopeWith(<Bookmark>[testBookmark(id: 7)]);
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scope,
      );

      await tester.tap(find.text(l10n.bookmarkRemove));
      await tester.pumpAndSettle();
      expect(find.text(l10n.bookmarkRemoveConfirmBody), findsOneWidget);

      await tester.tap(find.text(l10n.bookmarksCancel));
      await tester.pumpAndSettle();

      expect(scope.bookmarkRepository.removed, isEmpty);
    });

    testWidgets('confirming deletes and flips the screen to not-found', (
      tester,
    ) async {
      final scope = scopeWith(<Bookmark>[testBookmark(id: 7)]);
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scope,
      );

      await tester.tap(find.text(l10n.bookmarkRemove));
      await tester.pumpAndSettle();
      // The confirm button carries the same label as the row that opened it,
      // so target the one inside the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.bookmarkRemove),
        ),
      );
      await tester.pumpAndSettle();

      expect(scope.bookmarkRepository.removed, equals([BookmarkId(7)]));
      expect(find.text(l10n.bookmarksRemoved), findsOneWidget);
      // Nothing to pop back to in the harness, so the detail stays mounted
      // and re-resolves to its not-found state.
      expect(find.textContaining(l10n.bookmarkNotFound), findsOneWidget);
    });

    testWidgets('a failed delete reports the failure and keeps the bookmark', (
      tester,
    ) async {
      final scope = scopeWith(<Bookmark>[testBookmark(id: 7)]);
      await pumpInScope(
        tester,
        BookmarkDetailPage(id: BookmarkId(7)),
        scope: scope,
      );

      await tester.tap(find.text(l10n.bookmarkRemove));
      await tester.pumpAndSettle();
      scope.bookmarkRepository.failure = const InfrastructureError(
        'storage unavailable',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.bookmarkRemove),
        ),
      );
      // Pumped by hand rather than settled: `pumpAndSettle` runs the fake
      // clock past the SnackBar's auto-dismiss, so the message is gone before
      // it can be asserted on.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text(l10n.bookmarksRemoved), findsNothing);
      expect(find.text(l10n.commonError), findsOneWidget);

      await tester.pumpAndSettle();
      expect(scope.bookmarkRepository.stored, hasLength(1));
      // The screen ends up on the storage error rather than pretending the
      // bookmark is gone.
      expect(find.text('storage unavailable'), findsOneWidget);
    });
  });
}
