import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/device_album.dart';
import 'package:photonest/domain/errors/app_error.dart';

void main() {
  group('DeviceAlbum', () {
    test('rejects a blank album id', () {
      expect(
        () => DeviceAlbum(id: '  ', name: 'Camera', itemCount: 1),
        throwsA(isA<DomainError>()),
      );
    });

    test('identity is the album id, not the descriptive fields', () {
      // The device's gallery lets an album be renamed and its contents
      // change; a saved backup target must survive both.
      final before = DeviceAlbum(id: 'camera', name: 'Camera', itemCount: 640);
      final after = DeviceAlbum(id: 'camera', name: 'カメラ', itemCount: 641);
      expect(before, after);
      expect(before.hashCode, after.hashCode);
    });

    test('two different albums are different', () {
      expect(
        DeviceAlbum(id: 'camera', name: 'Camera', itemCount: 1),
        isNot(DeviceAlbum(id: 'screenshots', name: 'Camera', itemCount: 1)),
      );
    });

    test('toString names the album and what it holds', () {
      expect(
        DeviceAlbum(id: 'camera', name: 'Camera', itemCount: 640).toString(),
        'DeviceAlbum(camera, Camera, 640)',
      );
    });
  });
}
