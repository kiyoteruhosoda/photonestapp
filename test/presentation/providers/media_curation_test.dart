import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/providers/media_providers.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  MediaItem favorite(int id, {bool isFavorite = false}) =>
      testMediaItem(id: id).withFavorite(isFavorite);

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

  group('TrashedMediaNotifier', () {
    test('reads the trash, not the library', () async {
      final library = FakeMediaLibraryRepository(media: [favorite(1)])
        ..trashed = [favorite(9)];
      final scope = TestScope(mediaLibraryRepository: library);

      final items = await scope.container.read(trashedMediaProvider.future);

      expect(items.map((item) => item.id.value), [9]);
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
            .map((i) => i.id.value),
        [10],
      );
      expect(library.requestedTrashPages, hasLength(1));
    });

    test('an empty trash is an answer, not a failure', () async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
      );

      expect(await scope.container.read(trashedMediaProvider.future), isEmpty);
    });
  });
}
