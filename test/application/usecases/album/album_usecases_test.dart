import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeAlbumRepository repository;
  late FakeAlbumSnapshotRepository snapshots;
  late FakeSessionRepository sessions;
  late FakeApiEndpointRepository endpoints;
  late RecordingAppLogger logger;

  setUp(() {
    repository = FakeAlbumRepository();
    snapshots = FakeAlbumSnapshotRepository();
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
    logger = RecordingAppLogger();
  });

  /// Switches the signed-in account, as a login to another identity would.
  Future<void> switchAccount() => sessions.save(
    AuthSession(
      accessToken: 'other-access-token',
      refreshToken: 'other-refresh-token',
      email: 'other@example.com',
      scopes: const ['gui:view'],
    ),
  );

  group('ListAlbumsUseCase', () {
    ListAlbumsUseCase usecase() =>
        ListAlbumsUseCase(repository, snapshots, sessions, endpoints, logger);

    test('returns the repository albums and snapshots them', () async {
      repository.albums = [testAlbum(id: 1), testAlbum(id: 2)];

      final albums = await usecase().execute();

      expect(albums.map((album) => album.id.value), [1, 2]);
      expect(snapshots.savedAlbums, albums);
    });

    test('snapshots an empty list as a real answer', () async {
      await usecase().execute();
      expect(snapshots.savedAlbums, isEmpty);
      expect(snapshots.albumSaveCount, 1);
    });

    test('falls back to the snapshot when the server is unreachable', () async {
      snapshots.savedAlbums = [testAlbum(id: 7)];
      repository.failure = const NetworkUnreachableError('offline');

      final albums = await usecase().execute();

      expect(albums.map((album) => album.id.value), [7]);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('propagates the failure when there is no snapshot', () {
      repository.failure = const InfrastructureError('offline');
      expect(usecase().execute(), throwsA(isA<InfrastructureError>()));
    });

    test('does not mask a rejected identity with the snapshot', () {
      snapshots.savedAlbums = [testAlbum(id: 7)];
      repository.failure = const AuthenticationError('expired');

      expect(usecase().execute(), throwsA(isA<AuthenticationError>()));
    });

    test('a broken snapshot store degrades to server-only reads', () async {
      repository.albums = [testAlbum(id: 1)];
      snapshots.failure = const InfrastructureError('snapshot store gone');

      final albums = await usecase().execute();

      expect(albums, hasLength(1));
      // The write failure was logged, not swallowed silently.
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('a broken snapshot store still propagates the fetch failure', () {
      repository.failure = const InfrastructureError('offline');
      snapshots.failure = const InfrastructureError('snapshot store gone');

      expect(usecase().execute(), throwsA(isA<InfrastructureError>()));
    });

    test('does not write the snapshot when the identity changes '
        'mid-fetch', () async {
      // The fetch was authenticated as the original account; by the time it
      // lands another account is signed in, and the snapshot store files
      // rows under whoever is signed in now — writing would poison the new
      // account's offline view with the old account's albums.
      repository.albums = [testAlbum(id: 1)];
      repository.gate = switchAccount;

      final albums = await usecase().execute();

      expect(albums, hasLength(1));
      expect(snapshots.savedAlbums, isNull);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('does not serve the new identity\'s snapshot when the identity '
        'changes mid-fetch', () async {
      snapshots.savedAlbums = [testAlbum(id: 7)];
      repository.failure = const NetworkUnreachableError('offline');
      repository.gate = switchAccount;

      // The stored snapshot now belongs to the newly signed-in account, not
      // to whoever dispatched this request — the failure must surface.
      await expectLater(
        usecase().execute(),
        throwsA(isA<NetworkUnreachableError>()),
      );
    });
  });

  group('GetAlbumUseCase', () {
    GetAlbumUseCase usecase() =>
        GetAlbumUseCase(repository, snapshots, sessions, endpoints, logger);

    test('returns the album with its media and snapshots the page', () async {
      final detail = AlbumDetail(
        album: testAlbum(id: 3),
        media: [testMediaItem()],
      );
      repository.details = {AlbumId(3): detail};

      final loaded = await usecase().execute(AlbumId(3));

      expect(loaded, detail);
      expect(snapshots.savedDetails[(3, 1, 100)]?.media, hasLength(1));
    });

    test('snapshots each page under its own key', () async {
      repository.details = {
        AlbumId(3): AlbumDetail(
          album: testAlbum(id: 3),
          media: [for (var id = 1; id <= 3; id++) testMediaItem(id: id)],
        ),
      };

      await usecase().execute(AlbumId(3), mediaPage: 2, mediaPageSize: 2);

      expect(snapshots.savedDetails.keys, [(3, 2, 2)]);
    });

    test('returns null for an unknown album and drops its snapshot', () async {
      expect(await usecase().execute(AlbumId(9)), isNull);
      expect(snapshots.removedDetails, [AlbumId(9)]);
    });

    test('falls back to the snapshot when the server is unreachable', () async {
      final detail = AlbumDetail(
        album: testAlbum(id: 3),
        media: [testMediaItem()],
        mediaTotal: 1,
      );
      snapshots.savedDetails[(3, 1, 100)] = detail;
      repository.failure = const NetworkUnreachableError('offline');

      expect(await usecase().execute(AlbumId(3)), detail);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('only the snapshotted page can answer offline', () async {
      snapshots.savedDetails[(3, 1, 100)] = AlbumDetail(
        album: testAlbum(id: 3),
        media: [testMediaItem()],
      );
      repository.failure = const NetworkUnreachableError('offline');

      expect(
        usecase().execute(AlbumId(3), mediaPage: 2),
        throwsA(isA<NetworkUnreachableError>()),
      );
    });

    test('propagates the failure when there is no snapshot', () {
      repository.failure = const InfrastructureError('offline');
      expect(
        usecase().execute(AlbumId(1)),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('does not mask a rejected identity with the snapshot', () {
      snapshots.savedDetails[(1, 1, 100)] = AlbumDetail(
        album: testAlbum(id: 1),
        media: const [],
      );
      repository.failure = const AuthenticationError('expired');

      expect(
        usecase().execute(AlbumId(1)),
        throwsA(isA<AuthenticationError>()),
      );
    });

    test('a broken snapshot store degrades to server-only reads', () async {
      final detail = AlbumDetail(album: testAlbum(id: 3), media: const []);
      repository.details = {AlbumId(3): detail};
      snapshots.failure = const InfrastructureError('snapshot store gone');

      expect(await usecase().execute(AlbumId(3)), isNotNull);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('does not write the snapshot when the identity changes '
        'mid-fetch', () async {
      repository.details = {
        AlbumId(3): AlbumDetail(
          album: testAlbum(id: 3),
          media: [testMediaItem()],
        ),
      };
      // Same server, different account — the endpoint alone is not the
      // identity.
      repository.gate = switchAccount;

      expect(await usecase().execute(AlbumId(3)), isNotNull);
      expect(snapshots.savedDetails, isEmpty);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('does not drop the new identity\'s snapshot for an album the old '
        'identity cannot see', () async {
      // The vanished-album cleanup must only ever touch the snapshot of the
      // identity the answer belongs to.
      snapshots.savedDetails[(9, 1, 100)] = AlbumDetail(
        album: testAlbum(id: 9),
        media: const [],
      );
      repository.gate = switchAccount;

      expect(await usecase().execute(AlbumId(9)), isNull);
      expect(snapshots.removedDetails, isEmpty);
      expect(snapshots.savedDetails, hasLength(1));
    });
  });
}
