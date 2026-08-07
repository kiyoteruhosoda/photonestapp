import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // The Android/iOS sqflite plugin has no host implementation, so the tests
  // run the same production code against the FFI factory. `AppDatabase.open`
  // goes through the ambient `databaseFactory` for exactly this reason.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates the bookmarks table at the current schema version', () async {
    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final tables = await db.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.bookmarksTable),
    );
  });

  test('the bookmarks table has the columns the repository writes', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.bookmarksTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>['id', 'title', 'url', 'created_at']),
    );
  });

  test('enforces NOT NULL on the columns the domain always supplies', () {
    expect(
      db.insert(AppDatabase.bookmarksTable, <String, Object?>{'title': 'x'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('turns foreign keys on, which SQLite leaves off by default', () async {
    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(result.first.values.first, 1);
  });

  test('assigns ids automatically and never reuses them', () async {
    Future<int> insert(String title) =>
        db.insert(AppDatabase.bookmarksTable, <String, Object?>{
          'title': title,
          'url': 'https://a.example',
          'created_at': DateTime.utc(2026).toIso8601String(),
        });

    final first = await insert('a');
    final second = await insert('b');
    expect(second, greaterThan(first));

    await db.delete(
      AppDatabase.bookmarksTable,
      where: 'id = ?',
      whereArgs: <Object?>[second],
    );
    expect(await insert('c'), greaterThan(second));
  });

  test('re-opening an existing database does not re-run onCreate', () async {
    // A file-backed database, so the second open sees the first one's schema.
    final path = '${await databaseFactory.getDatabasesPath()}/reopen-test.db';
    await databaseFactory.deleteDatabase(path);

    final first = await AppDatabase.open(path: path);
    await first.insert(AppDatabase.bookmarksTable, <String, Object?>{
      'title': 'kept',
      'url': 'https://a.example',
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    await first.close();

    final second = await AppDatabase.open(path: path);
    addTearDown(() async {
      await second.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await second.query(AppDatabase.bookmarksTable), hasLength(1));
  });
}
