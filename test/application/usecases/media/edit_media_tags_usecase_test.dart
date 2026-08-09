import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/media/edit_media_tags_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/log_level.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeMediaTagRepository tags;
  late RecordingAppLogger logger;

  setUp(() {
    tags = FakeMediaTagRepository();
    logger = RecordingAppLogger();
  });

  EditMediaTagsUseCase usecase() => EditMediaTagsUseCase(tags, logger);

  test('reads the tags currently on a media item', () async {
    tags.byMedia[10] = [testTag(id: 1, name: 'Kyoto')];

    final current = await usecase().tagsOf(MediaId(10));

    expect(current.map((tag) => tag.name), ['Kyoto']);
  });

  test('an untagged media item is an answer, not a failure', () async {
    expect(await usecase().tagsOf(MediaId(10)), isEmpty);
  });

  test('passes the picker query and limit to the repository', () async {
    tags.library = [
      testTag(id: 1, name: 'Kyoto'),
      testTag(id: 2, name: 'Kyoto Station'),
      testTag(id: 3, name: 'Osaka'),
    ];

    final suggested = await usecase().suggest(query: 'kyo', limit: 5);

    expect(tags.suggestQueries, [('kyo', 5)]);
    expect(suggested.map((tag) => tag.id.value), [1, 2]);
  });

  test('replaces the whole set with the chosen tags', () async {
    final kyoto = testTag(id: 1, name: 'Kyoto');
    final osaka = testTag(id: 3, name: 'Osaka');
    tags.library = [kyoto, osaka];
    tags.byMedia[10] = [kyoto];

    final settled = await usecase().replace(MediaId(10), [kyoto, osaka]);

    expect(tags.replacements.single.$1, MediaId(10));
    expect(tags.replacements.single.$2.map((id) => id.value), [1, 3]);
    expect(settled.map((tag) => tag.id.value), [1, 3]);
  });

  test('clearing every tag sends an empty set rather than nothing', () async {
    tags.byMedia[10] = [testTag(id: 1, name: 'Kyoto')];

    final settled = await usecase().replace(MediaId(10), const []);

    expect(tags.replacements.single.$2, isEmpty);
    expect(settled, isEmpty);
  });

  test('the server settles the result, not what was asked for', () async {
    final kyoto = testTag(id: 1, name: 'Kyoto');
    // Another device deleted the second tag between the picker's read and
    // the save, so the server files the media under one tag.
    tags.settleTagsAt = [kyoto];

    final settled = await usecase().replace(MediaId(10), [
      kyoto,
      testTag(id: 2, name: 'Gone'),
    ]);

    expect(settled.map((tag) => tag.id.value), [1]);
  });

  test('logs the change by id, keeping tag names out of the log', () async {
    final kyoto = testTag(id: 1, name: 'Kyoto');
    tags.library = [kyoto];

    await usecase().replace(MediaId(10), [kyoto]);

    expect(logger.messagesAt(LogLevel.info), ['[Media] 10 tags: 1']);
  });

  test('logs an emptied tag set as none', () async {
    await usecase().replace(MediaId(10), const []);

    expect(logger.messagesAt(LogLevel.info), ['[Media] 10 tags: none']);
  });

  test('a repository failure reaches the caller', () {
    tags.failure = const NetworkUnreachableError('offline');

    expect(
      () => usecase().tagsOf(MediaId(10)),
      throwsA(isA<NetworkUnreachableError>()),
    );
    expect(() => usecase().suggest(), throwsA(isA<NetworkUnreachableError>()));
    expect(
      () => usecase().replace(MediaId(10), const []),
      throwsA(isA<NetworkUnreachableError>()),
    );
  });
}
