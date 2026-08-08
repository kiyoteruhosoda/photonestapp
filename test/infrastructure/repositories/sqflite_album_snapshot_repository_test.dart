import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_album_snapshot_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fakes.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late FakeSessionRepository sessions;
  late FakeApiEndpointRepository endpoints;

  final storedAt = DateTime.utc(2026, 8, 8, 12);

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
  });

  tearDown(() async {
    // One test closes the database itself to exercise error translation.
    if (db.isOpen) await db.close();
  });

  SqfliteAlbumSnapshotRepository repository() {
    return SqfliteAlbumSnapshotRepository(
      db,
      sessions,
      endpoints,
      clock: () => storedAt,
    );
  }

  AlbumDetail detail({
    int albumId = 3,
    List<AlbumMediaItem>? media,
    int? mediaTotal,
  }) {
    return AlbumDetail(
      album: testAlbum(id: albumId),
      media: media ?? [testAlbumMediaItem()],
      mediaTotal: mediaTotal,
    );
  }

  group('album list', () {
    test('misses before anything was saved', () async {
      expect(await repository().findAlbums(), isNull);
    });

    test('round-trips every album field', () async {
      final subject = repository();
      final albums = [
        Album(
          id: AlbumId(1),
          title: 'Trip',
          description: 'Summer trip',
          mediaCount: 2,
          coverMediaId: MediaId(10),
          createdAt: DateTime.utc(2026, 7, 1, 9, 30),
        ),
        // The optional fields absent, so their null round-trip is covered.
        Album(id: AlbumId(2), title: 'Empty', mediaCount: 0),
      ];
      await subject.saveAlbums(albums);

      final restored = await subject.findAlbums();

      expect(restored, hasLength(2));
      final first = restored!.first;
      expect(first.id, AlbumId(1));
      expect(first.title, 'Trip');
      expect(first.description, 'Summer trip');
      expect(first.mediaCount, 2);
      expect(first.coverMediaId, MediaId(10));
      expect(first.createdAt, DateTime.utc(2026, 7, 1, 9, 30));
      final second = restored[1];
      expect(second.description, isNull);
      expect(second.coverMediaId, isNull);
      expect(second.createdAt, isNull);
    });

    test('replaces the previous snapshot on save', () async {
      final subject = repository();
      await subject.saveAlbums([testAlbum(id: 1)]);
      await subject.saveAlbums([testAlbum(id: 2)]);

      final restored = await subject.findAlbums();
      expect(restored!.map((album) => album.id.value), [2]);
    });

    test('remembers an empty list as an answer, not a miss', () async {
      final subject = repository();
      await subject.saveAlbums(const []);

      expect(await subject.findAlbums(), isEmpty);
    });
  });

  group('album detail pages', () {
    test('misses before anything was saved', () async {
      expect(
        await repository().findDetail(
          AlbumId(3),
          mediaPage: 1,
          mediaPageSize: 100,
        ),
        isNull,
      );
    });

    test('round-trips a page, including the media fields', () async {
      final subject = repository();
      await subject.saveDetail(
        detail(
          media: [
            AlbumMediaItem(
              id: MediaId(10),
              filename: 'a.jpg',
              shotAt: DateTime.utc(2026, 8, 3, 12, 30),
            ),
            AlbumMediaItem(id: MediaId(11), filename: 'b.mp4', isVideo: true),
          ],
          mediaTotal: 150,
        ),
        mediaPage: 1,
        mediaPageSize: 100,
      );

      final restored = await subject.findDetail(
        AlbumId(3),
        mediaPage: 1,
        mediaPageSize: 100,
      );

      expect(restored!.album.id, AlbumId(3));
      expect(restored.mediaTotal, 150);
      expect(restored.media, hasLength(2));
      final photo = restored.media.first;
      expect(photo.id, MediaId(10));
      expect(photo.filename, 'a.jpg');
      expect(photo.shotAt, DateTime.utc(2026, 8, 3, 12, 30));
      expect(photo.isVideo, isFalse);
      final video = restored.media[1];
      expect(video.shotAt, isNull);
      expect(video.isVideo, isTrue);
    });

    test('a null media total stays unknown through the round-trip', () async {
      final subject = repository();
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);

      final restored = await subject.findDetail(
        AlbumId(3),
        mediaPage: 1,
        mediaPageSize: 100,
      );
      expect(restored!.mediaTotal, isNull);
    });

    test('keys pages by album, page, and page size', () async {
      final subject = repository();
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);

      expect(
        await subject.findDetail(AlbumId(3), mediaPage: 2, mediaPageSize: 100),
        isNull,
      );
      expect(
        await subject.findDetail(AlbumId(3), mediaPage: 1, mediaPageSize: 50),
        isNull,
      );
      expect(
        await subject.findDetail(AlbumId(4), mediaPage: 1, mediaPageSize: 100),
        isNull,
      );
    });

    test('removeDetail forgets every page of that album only', () async {
      final subject = repository();
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);
      await subject.saveDetail(detail(), mediaPage: 2, mediaPageSize: 100);
      await subject.saveDetail(
        detail(albumId: 4),
        mediaPage: 1,
        mediaPageSize: 100,
      );

      await subject.removeDetail(AlbumId(3));

      expect(
        await subject.findDetail(AlbumId(3), mediaPage: 1, mediaPageSize: 100),
        isNull,
      );
      expect(
        await subject.findDetail(AlbumId(3), mediaPage: 2, mediaPageSize: 100),
        isNull,
      );
      expect(
        await subject.findDetail(AlbumId(4), mediaPage: 1, mediaPageSize: 100),
        isNotNull,
      );
    });
  });

  group('scoping and failure translation', () {
    test('is scoped to the signed-in server and account', () async {
      final subject = repository();
      await subject.saveAlbums([testAlbum(id: 1)]);
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);

      endpoints = FakeApiEndpointRepository(Uri.parse('https://other.example'));

      expect(await repository().findAlbums(), isNull);
      expect(
        await repository().findDetail(
          AlbumId(3),
          mediaPage: 1,
          mediaPageSize: 100,
        ),
        isNull,
      );
    });

    test('misses instead of failing while signed out', () async {
      sessions = FakeSessionRepository();
      final subject = repository();

      expect(await subject.findAlbums(), isNull);
      // And writing while signed out silently does nothing.
      await subject.saveAlbums([testAlbum(id: 1)]);
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);
      await subject.removeDetail(AlbumId(3));
      expect(await subject.findAlbums(), isNull);
    });

    test('a corrupt payload reads as a typed error, not a crash', () async {
      final subject = repository();
      await subject.saveAlbums([testAlbum(id: 1)]);
      await db.update(AppDatabase.albumSnapshotsTable, {
        'payload': 'not json at all',
      });

      expect(subject.findAlbums(), throwsA(isA<InfrastructureError>()));
    });

    test('a payload of the wrong shape reads as a typed error', () async {
      final subject = repository();
      await subject.saveDetail(detail(), mediaPage: 1, mediaPageSize: 100);
      await db.update(AppDatabase.albumSnapshotsTable, {
        'payload': '{"album": 42, "media": []}',
      });

      expect(
        subject.findDetail(AlbumId(3), mediaPage: 1, mediaPageSize: 100),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('a closed database reads as a typed error', () async {
      final subject = repository();
      await db.close();

      expect(subject.findAlbums(), throwsA(isA<InfrastructureError>()));
      expect(
        subject.saveAlbums([testAlbum(id: 1)]),
        throwsA(isA<InfrastructureError>()),
      );
      expect(
        subject.removeDetail(AlbumId(3)),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('stamps rows with the injected clock, in UTC', () async {
      await repository().saveAlbums([testAlbum(id: 1)]);

      final rows = await db.query(AppDatabase.albumSnapshotsTable);
      expect(rows.single['stored_at'], storedAt.toIso8601String());
    });
  });
}
