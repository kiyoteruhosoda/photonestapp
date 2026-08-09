import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

void main() {
  group('MediaId', () {
    test('accepts a positive id', () {
      expect(MediaId(1).value, 1);
    });

    test('rejects zero and negatives', () {
      expect(() => MediaId(0), throwsA(isA<DomainError>()));
      expect(() => MediaId(-3), throwsA(isA<DomainError>()));
    });

    test('tryParse accepts a positive numeric string', () {
      expect(MediaId.tryParse('42'), MediaId(42));
    });

    test('tryParse rejects null, junk, and non-positive values', () {
      expect(MediaId.tryParse(null), isNull);
      expect(MediaId.tryParse('nope'), isNull);
      expect(MediaId.tryParse('0'), isNull);
    });

    test('equality is by value', () {
      expect(MediaId(7), MediaId(7));
      expect(MediaId(7).hashCode, MediaId(7).hashCode);
      expect(MediaId(7), isNot(MediaId(8)));
    });

    test('toString names the value', () {
      expect(MediaId(7).toString(), 'MediaId(7)');
    });
  });
}
