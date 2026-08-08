import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  final albumId = AlbumId(3);

  List<MediaItem> mediaRange(int from, int count) => [
    for (var i = from; i < from + count; i++) testMediaItem(id: i),
  ];

  AlbumDetail detailWith(List<MediaItem> media) =>
      AlbumDetail(album: testAlbum(id: 3), media: media);

  test(
    'loadMore appends the next page and advances the page counter',
    () async {
      final scope = TestScope(
        albumRepository: FakeAlbumRepository(
          details: {albumId: detailWith(mediaRange(1, 250))},
        ),
      );
      final notifier = scope.container.read(
        albumDetailProvider(albumId).notifier,
      );
      await scope.container.read(albumDetailProvider(albumId).future);

      await notifier.loadMore();
      var state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 200);
      expect(state.pagesLoaded, 2);
      expect(state.hasMore, isTrue);

      await notifier.loadMore();
      state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 250);
      expect(state.hasMore, isFalse);
    },
  );

  test('overlapping pages advance instead of re-requesting forever', () async {
    final repository = FakeAlbumRepository(
      details: {albumId: detailWith(mediaRange(1, 250))},
    );
    final scope = TestScope(albumRepository: repository);
    final notifier = scope.container.read(
      albumDetailProvider(albumId).notifier,
    );
    await scope.container.read(albumDetailProvider(albumId).future);

    // A new item lands at the front of the album between page reads, so
    // page 2 overlaps page 1 by one item and deduplication shortens the
    // accumulated list below a page-size multiple.
    repository.details[albumId] = detailWith([
      testMediaItem(id: 999),
      ...mediaRange(1, 250),
    ]);

    await notifier.loadMore();
    final afterOverlap = scope.container
        .read(albumDetailProvider(albumId))
        .value!;
    expect(afterOverlap.pagesLoaded, 2);
    // Page 2 held items 100..199 of the shifted album: item 100 was already
    // known, the other 99 appended — 199 in total, not a multiple of the
    // page size.
    expect(afterOverlap.media.length, 199);
    expect(afterOverlap.hasMore, isTrue);

    // The next request must be page 3 — not page 2 again.
    await notifier.loadMore();
    expect(repository.mediaPageRequests.map((request) => request.$2).toList(), [
      1,
      2,
      3,
    ]);
    final done = scope.container.read(albumDetailProvider(albumId)).value!;
    // Page 3 was the short final page, so paging stops even though the
    // deduplicated list never matched the advertised total exactly.
    expect(done.media.length, 250);
    expect(done.hasMore, isFalse);
  });

  test(
    'without an advertised total, an exactly full page keeps paging',
    () async {
      // 200 items and no `mediaTotal`: both pages are exactly full, so a
      // page-length fallback would have ended paging at 100.
      final repository = FakeAlbumRepository(
        details: {albumId: detailWith(mediaRange(1, 200))},
      )..reportsMediaTotal = false;
      final scope = TestScope(albumRepository: repository);
      final notifier = scope.container.read(
        albumDetailProvider(albumId).notifier,
      );
      await scope.container.read(albumDetailProvider(albumId).future);

      var state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 100);
      expect(state.hasMore, isTrue);

      await notifier.loadMore();
      state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 200);
      // Page 2 was full too, so the end is still unproven.
      expect(state.hasMore, isTrue);

      // Page 3 comes back empty — the short page that proves the end.
      await notifier.loadMore();
      state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 200);
      expect(state.hasMore, isFalse);
      expect(
        repository.mediaPageRequests.map((request) => request.$2).toList(),
        [1, 2, 3],
      );
    },
  );

  test('without an advertised total, a short first page ends paging', () async {
    final repository = FakeAlbumRepository(
      details: {albumId: detailWith(mediaRange(1, 30))},
    )..reportsMediaTotal = false;
    final scope = TestScope(albumRepository: repository);
    await scope.container.read(albumDetailProvider(albumId).future);

    final state = scope.container.read(albumDetailProvider(albumId)).value!;
    expect(state.media.length, 30);
    expect(state.hasMore, isFalse);
  });

  test(
    'a short page ends paging even when the advertised total is stale',
    () async {
      final repository = FakeAlbumRepository(
        details: {albumId: detailWith(mediaRange(1, 150))},
      );
      final scope = TestScope(albumRepository: repository);
      final notifier = scope.container.read(
        albumDetailProvider(albumId).notifier,
      );
      await scope.container.read(albumDetailProvider(albumId).future);

      // Media deleted mid-paging: page 2 comes back short of the advertised
      // 150-item total.
      repository.details[albumId] = detailWith(mediaRange(1, 120));

      await notifier.loadMore();
      final state = scope.container.read(albumDetailProvider(albumId)).value!;
      expect(state.media.length, 120);
      expect(state.hasMore, isFalse);
    },
  );
}
