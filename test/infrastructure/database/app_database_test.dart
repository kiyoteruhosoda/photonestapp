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

  test('creates every table at the current schema version', () async {
    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final tables = await db.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      containsAll(<String>[
        AppDatabase.uploadedPhotosTable,
        AppDatabase.mediaThumbnailsTable,
        AppDatabase.syncLeasesTable,
        AppDatabase.backupNotificationsTable,
        AppDatabase.albumSnapshotsTable,
      ]),
    );
  });

  test('enforces NOT NULL on the columns the repositories always supply', () {
    expect(
      db.insert(AppDatabase.uploadedPhotosTable, <String, Object?>{
        'local_id': 'x',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('turns foreign keys on, which SQLite leaves off by default', () async {
    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(result.first.values.first, 1);
  });

  test('creates the uploaded_photos table for the upload history', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.uploadedPhotosTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>['local_id', 'file_name', 'uploaded_at']),
    );
  });

  test('upgrading a v1 database adds the uploaded_photos table', () async {
    // Build a database exactly as schema v1 left it, then let AppDatabase
    // migrate it. This is the on-device path for anyone who installed the
    // app before the upload feature existed. v1 held only the template's
    // bookmarks table (dropped again by the v5 migration), so the fixture
    // spells its schema out literally.
    final path = '${await databaseFactory.getDatabasesPath()}/migrate-test.db';
    await databaseFactory.deleteDatabase(path);

    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TEXT NOT NULL
)
'''),
      ),
    );
    await v1.close();

    final migrated = await AppDatabase.open(path: path);
    addTearDown(() async {
      await migrated.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await migrated.getVersion(), AppDatabase.schemaVersion);
    final tables = await migrated.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.uploadedPhotosTable),
    );
  });

  test('upgrading drops the template bookmarks table', () async {
    // The bookmarks sample feature was removed in schema v5; a device
    // upgrading from any earlier version loses its table.
    final path = '${await databaseFactory.getDatabasesPath()}/migrate-drop.db';
    await databaseFactory.deleteDatabase(path);

    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TEXT NOT NULL
)
'''),
      ),
    );
    await v1.close();

    final migrated = await AppDatabase.open(path: path);
    addTearDown(() async {
      await migrated.close();
      await databaseFactory.deleteDatabase(path);
    });

    final tables = await migrated.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(tables.map((row) => row['name']), isNot(contains('bookmarks')));
  });

  test('creates the media_thumbnails table for the offline cache', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.mediaThumbnailsTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>[
        'account_key',
        'media_id',
        'size',
        'bytes',
        'byte_count',
        'fetched_at',
        'last_used_at',
      ]),
    );
  });

  test('upgrading a v2 database adds the media_thumbnails table', () async {
    // Build a database exactly as schema v2 left it, then let AppDatabase
    // migrate it — the on-device path for installs that predate the
    // thumbnail cache.
    final path = '${await databaseFactory.getDatabasesPath()}/migrate-v2.db';
    await databaseFactory.deleteDatabase(path);

    final v2 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.uploadedPhotosTable} (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
)
''');
        },
      ),
    );
    await v2.close();

    final migrated = await AppDatabase.open(path: path);
    addTearDown(() async {
      await migrated.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await migrated.getVersion(), AppDatabase.schemaVersion);
    final tables = await migrated.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.mediaThumbnailsTable),
    );
  });

  test('creates the backup_notifications table for the in-app list', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.backupNotificationsTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>[
        'id',
        'uploaded_count',
        'failed_count',
        'occurred_at',
        'read',
      ]),
    );
  });

  test('creates the album_snapshots table for offline metadata', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.albumSnapshotsTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>[
        'account_key',
        'snapshot_key',
        'payload',
        'stored_at',
      ]),
    );
  });

  test('upgrading a v6 database adds the album_snapshots table', () async {
    // Build a database exactly as schema v6 left it — every current table
    // except album_snapshots — then let AppDatabase migrate it. This is the
    // on-device path for installs that predate the offline album snapshot.
    final path = '${await databaseFactory.getDatabasesPath()}/migrate-v6.db';
    await databaseFactory.deleteDatabase(path);

    final v6 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE ${AppDatabase.uploadedPhotosTable} (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.mediaThumbnailsTable} (
  account_key TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  size INTEGER NOT NULL,
  bytes BLOB NOT NULL,
  byte_count INTEGER NOT NULL,
  fetched_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  PRIMARY KEY (account_key, media_id, size)
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.syncLeasesTable} (
  name TEXT NOT NULL PRIMARY KEY,
  holder TEXT NOT NULL,
  expires_at TEXT NOT NULL
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.backupNotificationsTable} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uploaded_count INTEGER NOT NULL,
  failed_count INTEGER NOT NULL,
  occurred_at TEXT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0
)
''');
        },
      ),
    );
    await v6.close();

    final migrated = await AppDatabase.open(path: path);
    addTearDown(() async {
      await migrated.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await migrated.getVersion(), AppDatabase.schemaVersion);
    final tables = await migrated.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.albumSnapshotsTable),
    );
  });

  test('creates the sync_leases table for cross-isolate leases', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppDatabase.syncLeasesTable})',
    );
    expect(
      columns.map((row) => row['name']),
      containsAll(<String>['name', 'holder', 'expires_at']),
    );
  });

  test('upgrading a v3 database adds the sync_leases table', () async {
    final path = '${await databaseFactory.getDatabasesPath()}/migrate-v3.db';
    await databaseFactory.deleteDatabase(path);

    final v3 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.uploadedPhotosTable} (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
)
''');
          await db.execute('''
CREATE TABLE ${AppDatabase.mediaThumbnailsTable} (
  account_key TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  size INTEGER NOT NULL,
  bytes BLOB NOT NULL,
  byte_count INTEGER NOT NULL,
  fetched_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  PRIMARY KEY (account_key, media_id, size)
)
''');
        },
      ),
    );
    await v3.close();

    final migrated = await AppDatabase.open(path: path);
    addTearDown(() async {
      await migrated.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await migrated.getVersion(), AppDatabase.schemaVersion);
    final tables = await migrated.query(
      'sqlite_master',
      columns: <String>['name'],
      where: 'type = ?',
      whereArgs: <Object?>['table'],
    );
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.syncLeasesTable),
    );
    // The v6 step of the same ladder added the notification table.
    expect(
      tables.map((row) => row['name']),
      contains(AppDatabase.backupNotificationsTable),
    );
  });

  test('re-opening an existing database does not re-run onCreate', () async {
    // A file-backed database, so the second open sees the first one's schema.
    final path = '${await databaseFactory.getDatabasesPath()}/reopen-test.db';
    await databaseFactory.deleteDatabase(path);

    final first = await AppDatabase.open(path: path);
    await first.insert(AppDatabase.uploadedPhotosTable, <String, Object?>{
      'account_key': 'server|user',
      'local_id': 'photo-1',
      'file_name': 'kept.jpg',
      'uploaded_at': DateTime.utc(2026).toIso8601String(),
    });
    await first.close();

    final second = await AppDatabase.open(path: path);
    addTearDown(() async {
      await second.close();
      await databaseFactory.deleteDatabase(path);
    });

    expect(await second.query(AppDatabase.uploadedPhotosTable), hasLength(1));
  });
}
