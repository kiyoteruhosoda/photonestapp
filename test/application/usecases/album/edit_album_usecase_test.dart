import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/album/edit_album_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeAlbumEditingRepository repository;
  late RecordingAppLogger logger;

  setUp(() {
    repository = FakeAlbumEditingRepository();
    logger = RecordingAppLogger();
  });

  EditAlbumUseCase usecase() => EditAlbumUseCase(repository, logger);

  group('create', () {
    test('trims the name so look-alike albums are not made', () async {
      await usecase().create('  Kyoto  ');

      expect(repository.created.single.title, 'Kyoto');
    });

    test('refuses a blank name without asking the server', () async {
      await expectLater(usecase().create('   '), throwsA(isA<DomainError>()));

      expect(repository.created, isEmpty);
    });

    test(
      'stores a blank description as none rather than an empty line',
      () async {
        await usecase().create('Kyoto', description: '   ');

        expect(repository.created.single.description, isNull);
      },
    );

    test('files the media it was given in the same request', () async {
      final album = await usecase().create(
        'Kyoto',
        mediaIds: <MediaId>[MediaId(7)],
      );

      // One request, not a create followed by a replacement: the album is
      // never briefly empty, and a failed second call cannot leave one
      // behind.
      expect(repository.created.single.mediaIds, [MediaId(7)]);
      expect(repository.replaced, isEmpty);
      expect(album.title, 'Kyoto');
    });
  });

  group('updateDetails', () {
    test('sends the trimmed name and description', () async {
      await usecase().updateDetails(
        AlbumId(4),
        title: ' Kyoto ',
        description: ' Autumn ',
      );

      expect(repository.updated.single.title, 'Kyoto');
      expect(repository.updated.single.description, 'Autumn');
    });

    test('clears a description the reader emptied', () async {
      await usecase().updateDetails(
        AlbumId(4),
        title: 'Kyoto',
        description: '',
      );

      expect(repository.updated.single.description, isNull);
    });

    test('refuses a blank name without asking the server', () async {
      await expectLater(
        usecase().updateDetails(AlbumId(4), title: ' '),
        throwsA(isA<DomainError>()),
      );

      expect(repository.updated, isEmpty);
    });
  });

  group('addMedia', () {
    test('sends what the album already held plus the new photo', () async {
      repository.mediaIds = {
        AlbumId(4): <MediaId>[MediaId(1), MediaId(2)],
      };

      final result = await usecase().addMedia(AlbumId(4), MediaId(3));

      // The endpoint replaces the whole set, so anything missing from this
      // list would be dropped from the album.
      expect(repository.replaced.single.mediaIds, [
        MediaId(1),
        MediaId(2),
        MediaId(3),
      ]);
      expect(result.added, isTrue);
    });

    test('appends rather than reorders what was already there', () async {
      repository.mediaIds = {
        AlbumId(4): <MediaId>[MediaId(9), MediaId(1)],
      };

      await usecase().addMedia(AlbumId(4), MediaId(5));

      expect(repository.replaced.single.mediaIds, [
        MediaId(9),
        MediaId(1),
        MediaId(5),
      ]);
    });

    test('writes nothing when the album already holds the photo', () async {
      repository.mediaIds = {
        AlbumId(4): <MediaId>[MediaId(1)],
      };

      final result = await usecase().addMedia(AlbumId(4), MediaId(1));

      expect(result.added, isFalse);
      // Not even the same set back: the endpoint replaces the whole album,
      // so a write built from ids read moments ago would undo whatever
      // another device changed in between — to say nothing.
      expect(repository.replaced, isEmpty);
      expect(result.album, isNull);
    });

    test('files the first photo into an empty album', () async {
      final result = await usecase().addMedia(AlbumId(4), MediaId(3));

      expect(repository.replaced.single.mediaIds, [MediaId(3)]);
      expect(result.added, isTrue);
    });

    test('lets an unreachable server surface', () async {
      repository.failure = const InfrastructureError('offline');

      await expectLater(
        usecase().addMedia(AlbumId(4), MediaId(3)),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });
}
