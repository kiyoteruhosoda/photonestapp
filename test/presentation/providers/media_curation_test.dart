import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/providers/album_providers.dart';
import 'package:photonest/presentation/providers/media_providers.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  MediaItem favorite(int id, {bool isFavorite = false}) =>
      testMediaItem(id: id).withFavorite(isFavorite);

  AlbumDetail albumOf(List<MediaItem> media) => AlbumDetail(
    album: testAlbum(id: 3, title: 'Holiday'),
    media: media,
  );

  group('MediaCurationNotifier', () {
    test(
      'marking a favourite writes the server answer into the timeline',
      () async {
        final curation = FakeMediaCurationRepository();
        final scope = TestScope(
          mediaLibraryRepository: FakeMediaLibraryRepository(
            media: [favorite(1), favorite(2)],
          ),
          mediaCurationRepository: curation,
        );
        await scope.container.read(libraryMediaProvider.future);

        final settled = await scope.container
            .read(mediaCurationProvider.notifier)
            .toggleFavorite(favorite(1));

        expect(settled, isTrue);
        expect(curation.favorites[1], isTrue);
        final media = scope.container.read(libraryMediaProvider).value!.media;
        expect(
          media.firstWhere((item) => item.id == MediaId(1)).isFavorite,
          isTrue,
        );
        // The other item is untouched.
        expect(
          media.firstWhere((item) => item.id == MediaId(2)).isFavorite,
          isFalse,
        );
      },
    );

    test('the server\'s answer wins over what was asked for', () async {
      // Another device turned it off in between; the screen must show what
      // is stored, not what this device asked for.
      final curation = FakeMediaCurationRepository()..settleFavoriteAt = false;
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1)],
        ),
        mediaCurationRepository: curation,
      );
      await scope.container.read(libraryMediaProvider.future);

      final settled = await scope.container
          .read(mediaCurationProvider.notifier)
          .toggleFavorite(favorite(1));

      expect(settled, isFalse);
      expect(
        scope.container
            .read(libraryMediaProvider)
            .value!
            .media
            .single
            .isFavorite,
        isFalse,
      );
    });

    test('a failed favourite leaves the item as it was', () async {
      final curation = FakeMediaCurationRepository()
        ..failure = const NetworkUnreachableError('offline');
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1, isFavorite: true)],
        ),
        mediaCurationRepository: curation,
      );
      await scope.container.read(libraryMediaProvider.future);

      final settled = await scope.container
          .read(mediaCurationProvider.notifier)
          .toggleFavorite(favorite(1, isFavorite: true));

      expect(settled, isNull);
      expect(
        scope.container
            .read(libraryMediaProvider)
            .value!
            .media
            .single
            .isFavorite,
        isTrue,
      );
      // The failure is state the screen can show, not a thrown exception.
      expect(
        scope.container.read(mediaCurationProvider).lastFailure,
        isNotNull,
      );
    });

    test('the failure clears once the screen has shown it', () async {
      final scope = TestScope(
        mediaCurationRepository: FakeMediaCurationRepository()
          ..failure = const NetworkUnreachableError('offline'),
      );
      await scope.container.read(libraryMediaProvider.future);
      await scope.container
          .read(mediaCurationProvider.notifier)
          .toggleFavorite(favorite(1));

      scope.container.read(mediaCurationProvider.notifier).acknowledgeFailure();

      expect(scope.container.read(mediaCurationProvider).lastFailure, isNull);
    });

    test('moving to the trash drops the item from the timeline', () async {
      final curation = FakeMediaCurationRepository();
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1), favorite(2)],
        ),
        mediaCurationRepository: curation,
      );
      await scope.container.read(libraryMediaProvider.future);

      final moved = await scope.container
          .read(mediaCurationProvider.notifier)
          .moveToTrash(favorite(1));

      expect(moved, isTrue);
      expect(curation.trashed, [MediaId(1)]);
      expect(
        scope.container
            .read(libraryMediaProvider)
            .value!
            .media
            .map((item) => item.id.value),
        [2],
      );
    });

    test('a failed delete keeps the item on screen', () async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1)],
        ),
        mediaCurationRepository: FakeMediaCurationRepository()
          ..failure = const NetworkUnreachableError('offline'),
      );
      await scope.container.read(libraryMediaProvider.future);

      final moved = await scope.container
          .read(mediaCurationProvider.notifier)
          .moveToTrash(favorite(1));

      expect(moved, isFalse);
      expect(
        scope.container.read(libraryMediaProvider).value!.media,
        hasLength(1),
      );
    });

    test(
      'restoring does not guess where the item belongs in the timeline',
      () async {
        final curation = FakeMediaCurationRepository();
        final scope = TestScope(
          mediaLibraryRepository: FakeMediaLibraryRepository(
            media: [favorite(2)],
          ),
          mediaCurationRepository: curation,
        );
        await scope.container.read(libraryMediaProvider.future);

        final restored = await scope.container
            .read(mediaCurationProvider.notifier)
            .restore(favorite(1));

        expect(restored, isTrue);
        expect(curation.restored, [MediaId(1)]);
        // The timeline is left alone — the next read places it in
        // capture order.
        expect(
          scope.container
              .read(libraryMediaProvider)
              .value!
              .media
              .map((item) => item.id.value),
          [2],
        );
      },
    );
  });

  group('MediaCurationNotifier — other lists', () {
    test('deleting also refreshes any loaded album grid', () async {
      // The viewer is shared. An album that keeps listing a deleted photo
      // would hand it back to the viewer on the next tap.
      final albums = FakeAlbumRepository(
        details: {
          AlbumId(3): albumOf([favorite(1), favorite(2)]),
        },
      );
      final scope = TestScope(
        albumRepository: albums,
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1), favorite(2)],
        ),
      );
      await scope.container.read(albumDetailProvider(AlbumId(3)).future);
      final readsBefore = albums.mediaPageRequests.length;

      await scope.container
          .read(mediaCurationProvider.notifier)
          .moveToTrash(favorite(1));
      await scope.container.read(albumDetailProvider(AlbumId(3)).future);

      expect(albums.mediaPageRequests.length, greaterThan(readsBefore));
    });

    test('a favourite mark does not reset a scrolled album grid', () async {
      // Tiles do not draw the favourite mark, so re-reading the album would
      // throw away the reader's position in exchange for nothing visible.
      final albums = FakeAlbumRepository(
        details: {
          AlbumId(3): albumOf([favorite(1)]),
        },
      );
      final scope = TestScope(
        albumRepository: albums,
        mediaLibraryRepository: FakeMediaLibraryRepository(
          media: [favorite(1)],
        ),
      );
      await scope.container.read(albumDetailProvider(AlbumId(3)).future);
      final readsBefore = albums.mediaPageRequests.length;

      await scope.container
          .read(mediaCurationProvider.notifier)
          .toggleFavorite(favorite(1));
      await scope.container.read(albumDetailProvider(AlbumId(3)).future);

      expect(albums.mediaPageRequests.length, readsBefore);
    });
  });

  group('MediaCurationNotifier — concurrency', () {
    test('a request for another item is not rejected by the first', () async {
      // The trash lists many rows and each disables only itself. A global
      // lock would let a second Restore be tapped and then report a failure
      // the server never saw.
      final gate = Completer<void>();
      final curation = FakeMediaCurationRepository()..gate = () => gate.future;
      final scope = TestScope(mediaCurationRepository: curation);
      await scope.container.read(libraryMediaProvider.future);
      final notifier = scope.container.read(mediaCurationProvider.notifier);

      final first = notifier.restore(favorite(1));
      final second = notifier.restore(favorite(2));
      gate.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(curation.restored, [MediaId(1), MediaId(2)]);
      expect(scope.container.read(mediaCurationProvider).lastFailure, isNull);
    });

    test('both items read as busy while their requests run', () async {
      final gate = Completer<void>();
      final scope = TestScope(
        mediaCurationRepository: FakeMediaCurationRepository()
          ..gate = () => gate.future,
      );
      await scope.container.read(libraryMediaProvider.future);
      final notifier = scope.container.read(mediaCurationProvider.notifier);

      final first = notifier.restore(favorite(1));
      final second = notifier.restore(favorite(2));

      final busy = scope.container.read(mediaCurationProvider);
      expect(busy.isBusy(MediaId(1)), isTrue);
      expect(busy.isBusy(MediaId(2)), isTrue);
      expect(busy.isBusy(MediaId(3)), isFalse);

      gate.complete();
      await first;
      await second;
      expect(scope.container.read(mediaCurationProvider).busyIds, isEmpty);
    });
  });

  group('TrashedMediaNotifier', () {
    test('reads the trash, not the library', () async {
      final library = FakeMediaLibraryRepository(media: [favorite(1)])
        ..trashed = [favorite(9)];
      final scope = TestScope(mediaLibraryRepository: library);

      final items = await scope.container.read(trashedMediaProvider.future);

      expect(items.media.map((item) => item.id.value), [9]);
      expect(library.requestedTrashPages, hasLength(1));
      // The ordinary listing was not used for this.
      expect(library.requestedPages, isEmpty);
    });

    test('a restored item is dropped without re-reading the list', () async {
      final library = FakeMediaLibraryRepository()
        ..trashed = [favorite(9), favorite(10)];
      final scope = TestScope(mediaLibraryRepository: library);
      await scope.container.read(trashedMediaProvider.future);

      scope.container.read(trashedMediaProvider.notifier).forget(MediaId(9));

      expect(
        scope.container
            .read(trashedMediaProvider)
            .value!
            .media
            .map((i) => i.id.value),
        [10],
      );
      expect(library.requestedTrashPages, hasLength(1));
    });

    test('pages through every window of the trash', () async {
      // More than one window's worth is ordinary after a bulk delete, and
      // the oldest items are the ones about to be purged — not being able
      // to reach them is not being able to rescue them.
      final library = FakeMediaLibraryRepository()
        ..trashed = [for (var i = 1; i <= 150; i++) favorite(i)];
      final scope = TestScope(mediaLibraryRepository: library);
      await scope.container.read(trashedMediaProvider.future);
      final notifier = scope.container.read(trashedMediaProvider.notifier);

      var state = scope.container.read(trashedMediaProvider).value!;
      expect(state.media, hasLength(libraryMediaPageSize));
      expect(state.hasMore, isTrue);

      await notifier.loadMore();

      state = scope.container.read(trashedMediaProvider).value!;
      expect(state.media, hasLength(150));
      expect(state.hasMore, isFalse);
      expect(library.requestedTrashPages, hasLength(2));
      expect(library.requestedTrashPages.last.$1, isNotNull);
    });

    test('loadMore is a no-op once the trash is fully read', () async {
      final library = FakeMediaLibraryRepository()..trashed = [favorite(9)];
      final scope = TestScope(mediaLibraryRepository: library);
      await scope.container.read(trashedMediaProvider.future);

      await scope.container.read(trashedMediaProvider.notifier).loadMore();

      expect(library.requestedTrashPages, hasLength(1));
    });

    test('a failed window keeps what is loaded and flags the retry', () async {
      final library = FakeMediaLibraryRepository()
        ..trashed = [for (var i = 1; i <= 150; i++) favorite(i)];
      final scope = TestScope(mediaLibraryRepository: library);
      await scope.container.read(trashedMediaProvider.future);

      library.failure = const NetworkUnreachableError('offline');
      await scope.container.read(trashedMediaProvider.notifier).loadMore();

      final state = scope.container.read(trashedMediaProvider).value!;
      expect(state.media, hasLength(libraryMediaPageSize));
      expect(state.loadMoreFailed, isTrue);
      expect(state.loadingMore, isFalse);
    });

    test('an empty trash is an answer, not a failure', () async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
      );

      expect(
        (await scope.container.read(trashedMediaProvider.future)).media,
        isEmpty,
      );
    });
  });
}
