import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/open_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeBookmarkRepository repository;
  late RecordingAppLogger logger;

  setUp(() {
    repository = FakeBookmarkRepository();
    logger = RecordingAppLogger();
  });

  BookmarkDraft draft({
    String title = 'Flutter',
    String url = 'https://docs.flutter.dev',
  }) => BookmarkDraft(title: title, url: Uri.parse(url));

  group('ListBookmarksUseCase', () {
    test('returns what the repository holds', () async {
      final useCase = ListBookmarksUseCase(repository);
      expect(await useCase.execute(), isEmpty);

      await repository.add(draft());
      expect(await useCase.execute(), hasLength(1));
    });

    test('propagates a storage failure instead of hiding it', () async {
      repository.failure = const InfrastructureError('disk gone');
      expect(
        ListBookmarksUseCase(repository).execute(),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('GetBookmarkUseCase', () {
    test('returns the stored bookmark', () async {
      final stored = await repository.add(draft());
      final found = await GetBookmarkUseCase(repository).execute(stored.id);
      expect(found, equals(stored));
    });

    test('returns null for an id nothing is stored under', () async {
      expect(
        await GetBookmarkUseCase(repository).execute(BookmarkId(404)),
        isNull,
      );
    });
  });

  group('AddBookmarkUseCase', () {
    test('stores the draft and returns it with an id', () async {
      final useCase = AddBookmarkUseCase(repository, logger);
      final stored = await useCase.execute(draft());

      expect(repository.added, hasLength(1));
      expect(stored.id.value, greaterThan(0));
      expect(stored.title, 'Flutter');
    });

    test('records what it stored', () async {
      await AddBookmarkUseCase(repository, logger).execute(draft());
      expect(
        logger.messagesAt(LogLevel.info),
        contains(contains('[Bookmarks] added')),
      );
    });
  });

  group('RemoveBookmarkUseCase', () {
    test('deletes the bookmark and records it', () async {
      final stored = await repository.add(draft());
      await RemoveBookmarkUseCase(repository, logger).execute(stored.id);

      expect(repository.removed, equals([stored.id]));
      expect(repository.stored, isEmpty);
      expect(
        logger.messagesAt(LogLevel.info),
        contains(contains('[Bookmarks] removed')),
      );
    });
  });

  group('OpenBookmarkUseCase', () {
    test('hands the URL to the launcher port and reports success', () async {
      final launcher = RecordingExternalLinkLauncher();
      final bookmark = await repository.add(draft());

      final opened = await OpenBookmarkUseCase(
        launcher,
        logger,
      ).execute(bookmark);

      expect(opened, isTrue);
      expect(launcher.opened, equals([bookmark.url]));
      expect(logger.messagesAt(LogLevel.info), contains(contains('opened')));
    });

    test('warns rather than throws when nothing can open the URL', () async {
      final launcher = RecordingExternalLinkLauncher(result: false);
      final bookmark = await repository.add(draft());

      final opened = await OpenBookmarkUseCase(
        launcher,
        logger,
      ).execute(bookmark);

      expect(opened, isFalse);
      expect(
        logger.messagesAt(LogLevel.warning),
        contains(contains('no handler')),
      );
    });
  });
}
