import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

void main() {
  group('BookmarkDraft', () {
    test('trims the title', () {
      final draft = BookmarkDraft(
        title: '  Flutter  ',
        url: Uri.parse('https://docs.flutter.dev'),
      );
      expect(draft.title, 'Flutter');
    });

    test('rejects a blank title', () {
      expect(
        () => BookmarkDraft(title: '   ', url: Uri.parse('https://a.example')),
        throwsA(isA<DomainError>()),
      );
    });

    test('rejects a title beyond the length limit', () {
      final tooLong = 'x' * (maxBookmarkTitleLength + 1);
      expect(
        () =>
            BookmarkDraft(title: tooLong, url: Uri.parse('https://a.example')),
        throwsA(isA<DomainError>()),
      );
      expect(
        BookmarkDraft(
          title: 'x' * maxBookmarkTitleLength,
          url: Uri.parse('https://a.example'),
        ).title.length,
        maxBookmarkTitleLength,
      );
    });

    test('accepts http and https', () {
      for (final url in ['http://a.example', 'https://a.example/x?y=1']) {
        expect(
          BookmarkDraft(title: 'ok', url: Uri.parse(url)).url.toString(),
          url,
        );
      }
    });

    test('rejects schemes the platform would hand somewhere unexpected', () {
      for (final url in [
        'file:///etc/passwd',
        'javascript:alert(1)',
        'flutterbase:///bookmarks/1',
        'mailto:a@example.com',
      ]) {
        expect(
          () => BookmarkDraft(title: 'nope', url: Uri.parse(url)),
          throwsA(isA<DomainError>()),
          reason: '$url should not be storable as a bookmark',
        );
      }
    });

    test('rejects a relative URL and one without a host', () {
      expect(
        () => BookmarkDraft(title: 'nope', url: Uri.parse('/bookmarks/1')),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => BookmarkDraft(title: 'nope', url: Uri.parse('https:///path')),
        throwsA(isA<DomainError>()),
      );
    });

    test('compares by value', () {
      final a = BookmarkDraft(title: 'x', url: Uri.parse('https://a.example'));
      final b = BookmarkDraft(title: 'x', url: Uri.parse('https://a.example'));
      final c = BookmarkDraft(title: 'y', url: Uri.parse('https://a.example'));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == Object(), isFalse);
      expect(a.toString(), contains('x'));
    });
  });

  group('Bookmark', () {
    final draft = BookmarkDraft(
      title: 'Flutter',
      url: Uri.parse('https://docs.flutter.dev'),
    );

    test('fromDraft carries the draft fields and normalises time to UTC', () {
      final local = DateTime(2026, 8, 3, 21, 30);
      final bookmark = Bookmark.fromDraft(
        id: BookmarkId(3),
        draft: draft,
        createdAt: local,
      );

      expect(bookmark.id, BookmarkId(3));
      expect(bookmark.title, 'Flutter');
      expect(bookmark.url, draft.url);
      expect(bookmark.createdAt.isUtc, isTrue);
      expect(bookmark.createdAt, local.toUtc());
    });

    test('is an entity: equality follows identity, not fields', () {
      final one = Bookmark.fromDraft(
        id: BookmarkId(1),
        draft: draft,
        createdAt: DateTime.utc(2026),
      );
      final renamed = Bookmark(
        id: BookmarkId(1),
        title: 'Renamed',
        url: Uri.parse('https://other.example'),
        createdAt: DateTime.utc(2030),
      );
      final other = Bookmark.fromDraft(
        id: BookmarkId(2),
        draft: draft,
        createdAt: DateTime.utc(2026),
      );

      expect(one, equals(renamed));
      expect(one.hashCode, renamed.hashCode);
      expect(one, isNot(equals(other)));
      expect(one == Object(), isFalse);
    });

    test('names itself in diagnostics', () {
      final bookmark = Bookmark.fromDraft(
        id: BookmarkId(1),
        draft: draft,
        createdAt: DateTime.utc(2026),
      );
      expect(bookmark.toString(), 'Bookmark(1, Flutter)');
    });
  });
}
