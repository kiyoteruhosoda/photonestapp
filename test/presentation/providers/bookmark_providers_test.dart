import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

void main() {
  late FakeBookmarkRepository repository;
  late RecordingAppLogger logger;

  setUp(() {
    repository = FakeBookmarkRepository();
    logger = RecordingAppLogger();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: <Override>[
        appLoggerProvider.overrideWithValue(logger),
        listBookmarksUseCaseProvider.overrideWithValue(
          ListBookmarksUseCase(repository),
        ),
        getBookmarkUseCaseProvider.overrideWithValue(
          GetBookmarkUseCase(repository),
        ),
        addBookmarkUseCaseProvider.overrideWithValue(
          AddBookmarkUseCase(repository, logger),
        ),
        removeBookmarkUseCaseProvider.overrideWithValue(
          RemoveBookmarkUseCase(repository, logger),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  BookmarkDraft draft({
    String title = 'Flutter',
    String url = 'https://docs.flutter.dev',
  }) => BookmarkDraft(title: title, url: Uri.parse(url));

  group('un-overridden providers', () {
    test('fail loudly rather than silently returning nothing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod wraps whatever a provider throws in a ProviderException,
      // so the assertion is on the message the developer will actually read.
      for (final read in <Object Function()>[
        () => container.read(listBookmarksUseCaseProvider),
        () => container.read(appLoggerProvider),
      ]) {
        expect(
          read,
          throwsA(
            isA<ProviderException>().having(
              (e) => e.toString(),
              'message',
              contains('read without an override'),
            ),
          ),
        );
      }
    });

    test('name themselves and where the override belongs', () {
      expect(
        missingOverrideMessage('somethingProvider'),
        allOf(
          contains('somethingProvider'),
          contains('provider_overrides.dart'),
        ),
      );
    });
  });

  group('BookmarkListNotifier', () {
    test('build loads the stored bookmarks', () async {
      await repository.add(draft(title: 'stored'));
      final container = buildContainer();

      final bookmarks = await container.read(bookmarkListProvider.future);
      expect(bookmarks.map((b) => b.title), equals(<String>['stored']));
    });

    test('starts loading before the first value arrives', () {
      final container = buildContainer();
      expect(container.read(bookmarkListProvider), isA<AsyncLoading<void>>());
    });

    test('add stores the draft and re-reads the list', () async {
      final container = buildContainer();
      await container.read(bookmarkListProvider.future);

      await container.read(bookmarkListProvider.notifier).add(draft());

      expect(repository.added, hasLength(1));
      expect(container.read(bookmarkListProvider).value, hasLength(1));
    });

    test('remove deletes and re-reads the list', () async {
      final stored = await repository.add(draft());
      final container = buildContainer();
      await container.read(bookmarkListProvider.future);

      await container.read(bookmarkListProvider.notifier).remove(stored.id);

      expect(repository.removed, equals(<BookmarkId>[stored.id]));
      expect(container.read(bookmarkListProvider).value, isEmpty);
    });

    test('reload re-reads without changing anything', () async {
      final container = buildContainer();
      await container.read(bookmarkListProvider.future);
      await repository.add(draft(title: 'added behind the screen'));

      await container.read(bookmarkListProvider.notifier).reload();

      expect(container.read(bookmarkListProvider).value, hasLength(1));
    });

    test('a failed write surfaces as an error state, not a crash', () async {
      final container = buildContainer();
      await container.read(bookmarkListProvider.future);
      repository.failure = const InfrastructureError('disk gone');

      await container.read(bookmarkListProvider.notifier).add(draft());

      final state = container.read(bookmarkListProvider);
      expect(state, isA<AsyncError<List<Bookmark>>>());
      expect((state as AsyncError<List<Bookmark>>).error, isA<AppError>());
    });

    test('a successful write reports true', () async {
      final container = buildContainer();
      await container.read(bookmarkListProvider.future);
      final notifier = container.read(bookmarkListProvider.notifier);

      expect(await notifier.add(draft()), isTrue);
      final stored = repository.stored.single;
      expect(await notifier.remove(stored.id), isTrue);
    });

    test(
      'a failed write reports false, so callers cannot claim success',
      () async {
        final container = buildContainer();
        await container.read(bookmarkListProvider.future);
        final notifier = container.read(bookmarkListProvider.notifier);
        repository.failure = const InfrastructureError('disk gone');

        expect(await notifier.add(draft()), isFalse);
        expect(await notifier.remove(BookmarkId(1)), isFalse);
      },
    );
  });

  group('bookmarkProvider', () {
    test('resolves a stored bookmark by id', () async {
      final stored = await repository.add(draft());
      final container = buildContainer();

      final found = await container.read(bookmarkProvider(stored.id).future);
      expect(found, equals(stored));
    });

    test('resolves null for an id nothing is stored under', () async {
      final container = buildContainer();
      expect(
        await container.read(bookmarkProvider(BookmarkId(404)).future),
        isNull,
      );
    });

    test(
      're-reads after the list changes, so a deletion is reflected',
      () async {
        final stored = await repository.add(draft());
        final container = buildContainer();
        expect(
          await container.read(bookmarkProvider(stored.id).future),
          isNotNull,
        );

        await container.read(bookmarkListProvider.notifier).remove(stored.id);

        expect(
          await container.read(bookmarkProvider(stored.id).future),
          isNull,
        );
      },
    );
  });
}
