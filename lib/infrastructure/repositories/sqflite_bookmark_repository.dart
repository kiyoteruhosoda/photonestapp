import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed [BookmarkRepository].
///
/// Timestamps are written in UTC and parsed back as UTC, so the value that
/// crosses into Domain never carries a device time zone — the UI converts on
/// display.
final class SqfliteBookmarkRepository implements BookmarkRepository {
  const SqfliteBookmarkRepository(this._db);

  final Database _db;

  static const String _table = AppDatabase.bookmarksTable;

  @override
  Future<List<Bookmark>> findAll() {
    return _guard('list', () async {
      final rows = await _db.query(_table, orderBy: 'created_at DESC, id DESC');
      return rows.map(_toBookmark).toList();
    });
  }

  @override
  Future<Bookmark?> findById(BookmarkId id) {
    return _guard('find', () async {
      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: <Object?>[id.value],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _toBookmark(rows.first);
    });
  }

  @override
  Future<Bookmark> add(BookmarkDraft draft) {
    return _guard('add', () async {
      // The clock lives here rather than in Domain: reading ambient state is
      // an Infrastructure concern, which is why `DateTime.now()` in Domain is
      // a `domain-clock` violation.
      final createdAt = DateTime.now().toUtc();
      final id = await _db.insert(_table, <String, Object?>{
        'title': draft.title,
        'url': draft.url.toString(),
        'created_at': createdAt.toIso8601String(),
      });
      return Bookmark.fromDraft(
        id: BookmarkId(id),
        draft: draft,
        createdAt: createdAt,
      );
    });
  }

  @override
  Future<void> remove(BookmarkId id) {
    return _guard('remove', () async {
      await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id.value]);
    });
  }

  Bookmark _toBookmark(Map<String, Object?> row) {
    return Bookmark(
      id: BookmarkId(row['id']! as int),
      title: row['title']! as String,
      url: Uri.parse(row['url']! as String),
      createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
    );
  }

  /// Translates a storage failure into the layer-neutral [InfrastructureError]
  /// so callers never have to catch a sqflite type.
  Future<T> _guard<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on DatabaseException catch (e) {
      throw InfrastructureError('bookmark $action failed', cause: e);
    }
  }
}
