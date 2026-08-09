import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/album_id.dart';

void main() {
  group('AlbumId', () {
    test('accepts a positive id', () {
      expect(AlbumId(1).value, 1);
    });

    test('rejects zero and negatives', () {
      expect(() => AlbumId(0), throwsA(isA<DomainError>()));
      expect(() => AlbumId(-3), throwsA(isA<DomainError>()));
    });

    test('tryParse accepts a positive numeric string', () {
      expect(AlbumId.tryParse('42'), AlbumId(42));
    });

    test('tryParse rejects null, junk, and non-positive values', () {
      expect(AlbumId.tryParse(null), isNull);
      expect(AlbumId.tryParse('not-a-number'), isNull);
      expect(AlbumId.tryParse('0'), isNull);
      expect(AlbumId.tryParse('-1'), isNull);
    });

    test('equality is by value', () {
      expect(AlbumId(7), AlbumId(7));
      expect(AlbumId(7).hashCode, AlbumId(7).hashCode);
      expect(AlbumId(7), isNot(AlbumId(8)));
    });

    test('toString names the value', () {
      expect(AlbumId(7).toString(), 'AlbumId(7)');
    });
  });
}
