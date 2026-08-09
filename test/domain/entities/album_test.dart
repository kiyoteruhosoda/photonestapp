import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

void main() {
  Album build({int id = 1, String title = 'Trip'}) {
    return Album(
      id: AlbumId(id),
      title: title,
      mediaCount: 3,
      coverMediaId: MediaId(9),
      createdAt: DateTime.utc(2026),
    );
  }

  group('Album', () {
    test('identity is the id — a renamed album is the same album', () {
      expect(build(title: 'Trip'), build(title: 'Renamed'));
      expect(build().hashCode, build(title: 'Renamed').hashCode);
      expect(build(id: 1), isNot(build(id: 2)));
    });

    test('toString names id and title', () {
      expect(build().toString(), 'Album(1, Trip)');
    });
  });

  group('MediaItem', () {
    MediaItem buildItem({int id = 5, String filename = 'a.jpg'}) {
      return MediaItem(
        id: MediaId(id),
        filename: filename,
        shotAt: DateTime.utc(2026),
      );
    }

    test('identity is the media id', () {
      expect(buildItem(filename: 'a.jpg'), buildItem(filename: 'b.jpg'));
      expect(buildItem(id: 5), isNot(buildItem(id: 6)));
      expect(buildItem().hashCode, buildItem().hashCode);
    });

    test('toString names id and filename', () {
      expect(buildItem().toString(), 'MediaItem(5, a.jpg)');
    });
  });

  group('AlbumDetail', () {
    test('identity follows the album', () {
      final a = AlbumDetail(album: build(), media: const []);
      final b = AlbumDetail(
        album: build(),
        media: [MediaItem(id: MediaId(1), filename: 'x.jpg')],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString names the album and the paging position', () {
      final detail = AlbumDetail(
        album: build(),
        media: const [],
        mediaTotal: 3,
      );
      expect(detail.toString(), 'AlbumDetail(1, 0 of 3 media)');
    });

    test('an unreported mediaTotal stays unknown, not the page length', () {
      // Defaulting to the page length would end paging silently whenever a
      // page happened to be exactly full.
      final detail = AlbumDetail(
        album: build(),
        media: [MediaItem(id: MediaId(1), filename: 'x.jpg')],
      );
      expect(detail.mediaTotal, isNull);
      expect(detail.toString(), 'AlbumDetail(1, 1 of ? media)');
    });

    test('mediaTotal reports the whole album beyond the page', () {
      final detail = AlbumDetail(
        album: build(),
        media: [MediaItem(id: MediaId(1), filename: 'x.jpg')],
        mediaTotal: 500,
      );
      expect(detail.mediaTotal, 500);
    });
  });
}
