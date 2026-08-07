import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

void main() {
  group('BookmarkId', () {
    test('accepts a positive row id', () {
      expect(BookmarkId(1).value, 1);
      expect(BookmarkId(9999).value, 9999);
    });

    test('rejects zero and negative ids', () {
      expect(() => BookmarkId(0), throwsA(isA<DomainError>()));
      expect(() => BookmarkId(-1), throwsA(isA<DomainError>()));
    });

    test('compares by value, not identity', () {
      expect(BookmarkId(7), equals(BookmarkId(7)));
      expect(BookmarkId(7).hashCode, BookmarkId(7).hashCode);
      expect(BookmarkId(7), isNot(equals(BookmarkId(8))));
      // Used as a Riverpod family key, which needs both == and hashCode.
      expect(<BookmarkId, String>{BookmarkId(7): 'a'}[BookmarkId(7)], 'a');
    });

    test('is not equal to another type', () {
      expect(BookmarkId(7) == Object(), isFalse);
    });

    test('names itself in diagnostics', () {
      expect(BookmarkId(7).toString(), 'BookmarkId(7)');
    });

    group('tryParse — the deep-link entry point', () {
      test('parses a positive integer path segment', () {
        expect(BookmarkId.tryParse('42'), equals(BookmarkId(42)));
      });

      test('returns null instead of throwing for junk input', () {
        expect(BookmarkId.tryParse(null), isNull);
        expect(BookmarkId.tryParse(''), isNull);
        expect(BookmarkId.tryParse('abc'), isNull);
        expect(BookmarkId.tryParse('1.5'), isNull);
        expect(BookmarkId.tryParse('0'), isNull);
        expect(BookmarkId.tryParse('-3'), isNull);
      });
    });
  });
}
