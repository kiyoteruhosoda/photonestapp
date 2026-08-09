import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';

void main() {
  group('TagId', () {
    test('rejects ids the server could never issue', () {
      expect(() => TagId(0), throwsA(isA<DomainError>()));
      expect(() => TagId(-1), throwsA(isA<DomainError>()));
    });

    test('is equal by value, so the same tag is one entry in a set', () {
      expect(TagId(7), TagId(7));
      expect({TagId(7), TagId(7)}, hasLength(1));
      expect(TagId(7), isNot(TagId(8)));
    });

    test('describes itself with its id', () {
      expect(TagId(7).toString(), 'TagId(7)');
    });
  });
}
