import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/errors/app_error.dart';

void main() {
  group('LocalPhoto', () {
    test('rejects a blank local id', () {
      expect(
        () => LocalPhoto(
          localId: '  ',
          fileName: 'a.jpg',
          takenAt: DateTime.utc(2026),
        ),
        throwsA(isA<DomainError>()),
      );
    });

    test('normalises the capture instant to UTC', () {
      final photo = LocalPhoto(
        localId: 'asset-1',
        fileName: 'a.jpg',
        takenAt: DateTime(2026, 8, 3, 21, 30),
      );
      expect(photo.takenAt.isUtc, isTrue);
    });

    test('identity is the local id, not the descriptive fields', () {
      LocalPhoto build(String fileName) => LocalPhoto(
        localId: 'asset-1',
        fileName: fileName,
        takenAt: DateTime.utc(2026),
      );
      expect(build('a.jpg'), build('renamed.jpg'));
      expect(build('a.jpg').hashCode, build('renamed.jpg').hashCode);
    });

    test('toString names id and file', () {
      final photo = LocalPhoto(
        localId: 'asset-1',
        fileName: 'a.jpg',
        takenAt: DateTime.utc(2026),
      );
      expect(photo.toString(), contains('asset-1'));
      expect(photo.toString(), contains('a.jpg'));
    });
  });
}
