import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/albums/album_detail_page.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  AlbumDetail detail({int mediaCount = 2, Set<int> videoIds = const {}}) =>
      AlbumDetail(
        album: testAlbum(id: 3, title: 'Holiday'),
        media: [
          for (var i = 1; i <= mediaCount; i++)
            testAlbumMediaItem(
              id: i,
              filename: 'IMG_$i.jpg',
              isVideo: videoIds.contains(i),
            ),
        ],
      );

  testWidgets('a null id renders the not-found state', (tester) async {
    await pumpInScope(tester, const AlbumDetailPage(id: null));
    expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
  });

  testWidgets('an unknown album renders the not-found state', (tester) async {
    final scope = TestScope();
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(9)), scope: scope);
    expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
  });

  testWidgets('shows the title and one tile per media item', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(details: {AlbumId(3): detail()}),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    expect(find.text('Holiday'), findsOneWidget);
    expect(find.byType(ThumbnailImage), findsNWidgets(2));
    expect(scope.mediaThumbnailRepository.fetched, hasLength(2));
  });

  testWidgets('an album with no media shows the empty state', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {AlbumId(3): detail(mediaCount: 0)},
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);
    expect(find.text(l10n.albumEmpty), findsOneWidget);
  });

  testWidgets('a failing load renders the error state', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository()
        ..failure = const InfrastructureError('boom'),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);
    expect(find.text('boom'), findsNothing);
    // A response the server did send (not a transport failure) stays
    // generic rather than telling the user to check their connection.
    expect(find.text(l10n.commonError), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });

  testWidgets('offline, the saved snapshot still renders the grid from '
      'cached thumbnails', (tester) async {
    // The cold-start regression from PR #6: server unreachable, but this
    // album's first page was snapshotted and its thumbnails cached on an
    // earlier run — the grid must render from local data alone.
    final snapshots = FakeAlbumSnapshotRepository();
    snapshots.savedDetails[(3, 1, albumMediaPageSize)] = detail();
    final cache = FakeMediaThumbnailCacheRepository();
    cache.entries[(1, 256)] = testPngBytes;
    cache.entries[(2, 256)] = testPngBytes;
    final scope = TestScope(
      albumRepository: FakeAlbumRepository()
        ..failure = const NetworkUnreachableError('offline'),
      albumSnapshotRepository: snapshots,
      mediaThumbnailRepository: FakeMediaThumbnailRepository()
        ..failure = const NetworkUnreachableError('offline'),
      mediaThumbnailCacheRepository: cache,
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    expect(find.text('Holiday'), findsOneWidget);
    expect(find.byType(ThumbnailImage), findsNWidgets(2));
    // The pixels came from the persistent cache, not the network.
    expect(scope.mediaThumbnailRepository.fetched, isEmpty);
  });

  testWidgets('tapping a tile opens the full-screen preview and taps close', (
    tester,
  ) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {AlbumId(3): detail(mediaCount: 1)},
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    await tester.tap(find.byType(ThumbnailImage).first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    // The preview asks for the large rendition.
    expect(
      scope.mediaThumbnailRepository.fetched.map((entry) => entry.$2),
      contains(2048),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a video tile carries the play badge', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {
          AlbumId(3): detail(mediaCount: 2, videoIds: {2}),
        },
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('tapping a video asks for a playback source, and a not-ready '
      'answer explains itself', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {
          AlbumId(3): detail(mediaCount: 1, videoIds: {1}),
        },
      ),
    );
    scope.mediaPlaybackRepository.failure = const InfrastructureError(
      'processing',
      code: 'not_ready',
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    await tester.tap(find.byType(ThumbnailImage).first);
    await tester.pumpAndSettle();

    expect(scope.mediaPlaybackRepository.requested, hasLength(1));
    expect(find.text(l10n.videoNotReady), findsOneWidget);
    // No full-image request was made for the 2048 rendition.
    expect(
      scope.mediaThumbnailRepository.fetched.map((entry) => entry.$2),
      isNot(contains(2048)),
    );
  });

  testWidgets('a large album pages in as the grid builds', (tester) async {
    // 150 items: page one (100) renders first, and building the tail tile
    // triggers the second page without any user gesture beyond scrolling.
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {AlbumId(3): detail(mediaCount: 150)},
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    // Only page one travelled over the wire on the first fetch.
    expect(scope.albumRepository.mediaPageRequests.first.$2, 1);

    // Scroll to the bottom so the tail tiles (and the trigger) build.
    await tester.fling(find.byType(GridView), const Offset(0, -50000), 10000);
    await tester.pumpAndSettle();

    final loaded = scope.container.read(albumDetailProvider(AlbumId(3))).value!;
    expect(loaded.media.length, 150);
    expect(loaded.hasMore, isFalse);
    // Page one, page two — and nothing else.
    expect(scope.albumRepository.mediaPageRequests.map((r) => r.$2).toSet(), {
      1,
      2,
    });
  });
}
