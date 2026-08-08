import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  List<MediaItem> mediaRange(int from, int count) => [
    for (var i = from; i < from + count; i++) testMediaItem(id: i),
  ];

  test('the first page is what the timeline opens with', () async {
    final scope = TestScope(
      mediaLibraryRepository: FakeMediaLibraryRepository(
        media: mediaRange(1, 250),
      ),
    );

    final state = await scope.container.read(libraryMediaProvider.future);

    expect(state.media, hasLength(libraryMediaPageSize));
    expect(state.pagesLoaded, 1);
    expect(state.hasMore, isTrue);
  });

  test('loadMore appends the next page and advances the counter', () async {
    final scope = TestScope(
      mediaLibraryRepository: FakeMediaLibraryRepository(
        media: mediaRange(1, 250),
      ),
    );
    final notifier = scope.container.read(libraryMediaProvider.notifier);
    await scope.container.read(libraryMediaProvider.future);

    await notifier.loadMore();
    var state = scope.container.read(libraryMediaProvider).value!;
    expect(state.media, hasLength(200));
    expect(state.pagesLoaded, 2);
    expect(state.hasMore, isTrue);

    await notifier.loadMore();
    state = scope.container.read(libraryMediaProvider).value!;
    expect(state.media, hasLength(250));
    // A short page ends the paging whatever `hasNext` said.
    expect(state.hasMore, isFalse);
  });

  test('media added between page reads is not rendered twice', () async {
    final repository = FakeMediaLibraryRepository(media: mediaRange(1, 150));
    final scope = TestScope(mediaLibraryRepository: repository);
    final notifier = scope.container.read(libraryMediaProvider.notifier);
    await scope.container.read(libraryMediaProvider.future);

    // An upload lands at the front of the library between page reads, so
    // page 2 overlaps page 1 by one item.
    repository.media = [testMediaItem(id: 999), ...repository.media];
    await notifier.loadMore();

    final state = scope.container.read(libraryMediaProvider).value!;
    final ids = state.media.map((item) => item.id.value).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(state.pagesLoaded, 2);
  });

  test(
    'a failed loadMore keeps the loaded media and flags the retry',
    () async {
      final repository = FakeMediaLibraryRepository(media: mediaRange(1, 250));
      final scope = TestScope(mediaLibraryRepository: repository);
      final notifier = scope.container.read(libraryMediaProvider.notifier);
      await scope.container.read(libraryMediaProvider.future);

      repository.failure = const NetworkUnreachableError('offline');
      await notifier.loadMore();

      var state = scope.container.read(libraryMediaProvider).value!;
      expect(state.media, hasLength(libraryMediaPageSize));
      expect(state.loadMoreFailed, isTrue);
      expect(state.loadingMore, isFalse);

      // The retry picks up where it left off rather than restarting.
      repository.failure = null;
      await notifier.loadMore();
      state = scope.container.read(libraryMediaProvider).value!;
      expect(state.media, hasLength(200));
      expect(state.loadMoreFailed, isFalse);
    },
  );

  test('loadMore is a no-op once the library is fully read', () async {
    final repository = FakeMediaLibraryRepository(media: mediaRange(1, 10));
    final scope = TestScope(mediaLibraryRepository: repository);
    final notifier = scope.container.read(libraryMediaProvider.notifier);
    await scope.container.read(libraryMediaProvider.future);
    expect(repository.requestedPages, hasLength(1));

    await notifier.loadMore();

    expect(repository.requestedPages, hasLength(1));
  });

  test('reload starts the timeline over from the first page', () async {
    final repository = FakeMediaLibraryRepository(media: mediaRange(1, 250));
    final scope = TestScope(mediaLibraryRepository: repository);
    final notifier = scope.container.read(libraryMediaProvider.notifier);
    await scope.container.read(libraryMediaProvider.future);
    await notifier.loadMore();

    await notifier.reload();

    final state = scope.container.read(libraryMediaProvider).value!;
    expect(state.pagesLoaded, 1);
    expect(state.media, hasLength(libraryMediaPageSize));
    expect(repository.requestedPages.last, (1, libraryMediaPageSize));
  });
}
