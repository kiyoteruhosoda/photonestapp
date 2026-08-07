import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';

import '../../../support/fakes.dart';

void main() {
  group('ListAlbumsUseCase', () {
    test('returns the repository albums', () async {
      final repository = FakeAlbumRepository(
        albums: [testAlbum(id: 1), testAlbum(id: 2)],
      );
      final albums = await ListAlbumsUseCase(repository).execute();
      expect(albums.map((album) => album.id.value), [1, 2]);
    });

    test('propagates repository failures', () {
      final repository = FakeAlbumRepository()
        ..failure = const InfrastructureError('offline');
      expect(
        ListAlbumsUseCase(repository).execute(),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('GetAlbumUseCase', () {
    test('returns the album with its media', () async {
      final detail = AlbumDetail(
        album: testAlbum(id: 3),
        media: [testAlbumMediaItem()],
      );
      final repository = FakeAlbumRepository(details: {AlbumId(3): detail});

      expect(await GetAlbumUseCase(repository).execute(AlbumId(3)), detail);
    });

    test('returns null for an unknown album', () async {
      expect(
        await GetAlbumUseCase(FakeAlbumRepository()).execute(AlbumId(9)),
        isNull,
      );
    });

    test('propagates repository failures', () {
      final repository = FakeAlbumRepository()
        ..failure = const AuthenticationError('expired');
      expect(
        GetAlbumUseCase(repository).execute(AlbumId(1)),
        throwsA(isA<AuthenticationError>()),
      );
    });
  });
}
