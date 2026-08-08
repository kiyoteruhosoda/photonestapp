import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and migrates the app's SQLite database.
///
/// Every schema change goes through [schemaVersion] and [_upgrade] so a
/// device that skipped releases still lands on the current shape. Opening
/// goes through the ambient [databaseFactory] rather than the top-level
/// `openDatabase`, which is what lets the tests point the same code at an
/// in-memory database via `sqflite_common_ffi`.
final class AppDatabase {
  AppDatabase._();

  /// File name under the platform's database directory.
  static const String fileName = 'flutterbase.db';

  /// Bump this together with a new `if (from < n)` branch in [_upgrade].
  static const int schemaVersion = 4;

  /// Table holding the bookmarks sample feature.
  static const String bookmarksTable = 'bookmarks';

  /// Table remembering which device photos were already uploaded.
  static const String uploadedPhotosTable = 'uploaded_photos';

  /// Table caching downloaded server thumbnails for offline rendering.
  static const String mediaThumbnailsTable = 'media_thumbnails';

  /// Table holding cross-isolate leases, e.g. the auto-upload sync lease.
  static const String syncLeasesTable = 'sync_leases';

  /// Opens the database, creating or migrating the schema as needed.
  ///
  /// Pass [path] to open somewhere other than the platform default — tests
  /// pass `inMemoryDatabasePath`.
  static Future<Database> open({String? path}) async {
    final resolved = path ?? p.join(await getDatabasesPath(), fileName);
    return databaseFactory.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _configure,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
  }

  static Future<void> _configure(Database db) async {
    // Off by default in SQLite; without it `REFERENCES` clauses are inert.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
CREATE TABLE $bookmarksTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
    await db.execute(_createUploadedPhotos);
    await db.execute(_createMediaThumbnails);
    await db.execute(_createSyncLeases);
  }

  /// `local_id` is the platform's asset identifier; `account_key` names the
  /// server + account the photo was sent to. The pair is the primary key:
  /// the same photo uploaded to two accounts is two history rows, so
  /// signing into another account never inherits the first one's history.
  static const String _createUploadedPhotos =
      '''
CREATE TABLE $uploadedPhotosTable (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
)
''';

  /// One row per (destination, media, rendition size). `byte_count`
  /// duplicates `length(bytes)` so the eviction budget is a cheap SUM, and
  /// `last_used_at` orders the LRU eviction.
  static const String _createMediaThumbnails =
      '''
CREATE TABLE $mediaThumbnailsTable (
  account_key TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  size INTEGER NOT NULL,
  bytes BLOB NOT NULL,
  byte_count INTEGER NOT NULL,
  fetched_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  PRIMARY KEY (account_key, media_id, size)
)
''';

  /// One row per named lease. The foreground app and WorkManager's headless
  /// engine are separate isolates sharing only this database, so this table
  /// is what lets exactly one of them run a sync pass at a time.
  static const String _createSyncLeases =
      '''
CREATE TABLE $syncLeasesTable (
  name TEXT NOT NULL PRIMARY KEY,
  holder TEXT NOT NULL,
  expires_at TEXT NOT NULL
)
''';

  /// Applies the migrations between two schema versions.
  ///
  /// Written as a fall-through ladder — `if (from < 2) { … }`, then
  /// `if (from < 3) { … }` — so upgrading across several releases at once
  /// runs each step in order.
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute(_createUploadedPhotos);
    }
    if (from < 3) {
      await db.execute(_createMediaThumbnails);
    }
    if (from < 4) {
      await db.execute(_createSyncLeases);
    }
  }
}
