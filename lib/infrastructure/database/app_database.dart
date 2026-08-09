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
  static const int schemaVersion = 9;

  /// Table remembering which device photos were already uploaded.
  static const String uploadedPhotosTable = 'uploaded_photos';

  /// Table caching downloaded server thumbnails for offline rendering.
  static const String mediaThumbnailsTable = 'media_thumbnails';

  /// Table holding cross-isolate leases, e.g. the auto-upload sync lease.
  static const String syncLeasesTable = 'sync_leases';

  /// Table holding backup-result notifications for the in-app list.
  static const String backupNotificationsTable = 'backup_notifications';

  /// Table snapshotting album metadata (list and detail pages) for offline
  /// fallback rendering.
  static const String albumSnapshotsTable = 'album_snapshots';

  /// Table remembering which device photos failed to upload, and why.
  static const String uploadFailuresTable = 'upload_failures';

  /// Table holding the resume point of chunked uploads still in flight.
  static const String uploadResumptionsTable = 'upload_resumptions';

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
    await db.execute(_createUploadedPhotos);
    await db.execute(_createMediaThumbnails);
    await db.execute(_createSyncLeases);
    await db.execute(_createBackupNotifications);
    await db.execute(_createAlbumSnapshots);
    await db.execute(_createUploadFailures);
    await db.execute(_createUploadResumptions);
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

  /// One row per backup pass that attempted at least one upload. `read`
  /// flips to 1 when the notification list is opened; the header badge is a
  /// cheap COUNT over the zeros. Written by both isolates.
  static const String _createBackupNotifications =
      '''
CREATE TABLE $backupNotificationsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uploaded_count INTEGER NOT NULL,
  failed_count INTEGER NOT NULL,
  occurred_at TEXT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0
)
''';

  /// One row per remembered server answer about albums: the album list, or
  /// one page of one album's detail — `snapshot_key` says which. `payload`
  /// is the JSON the repository serialises; `stored_at` records when the
  /// answer was fetched. Keyed by server + account like the thumbnail
  /// cache, because album and media ids are only unique per server.
  static const String _createAlbumSnapshots =
      '''
CREATE TABLE $albumSnapshotsTable (
  account_key TEXT NOT NULL,
  snapshot_key TEXT NOT NULL,
  payload TEXT NOT NULL,
  stored_at TEXT NOT NULL,
  PRIMARY KEY (account_key, snapshot_key)
)
''';

  /// One row per device photo that is currently failing to upload, scoped
  /// to the account it was being sent to. `attempts` counts consecutive
  /// failures, which is what separates a photo the next pass will fix from
  /// one that will never succeed (an unsupported format). A successful
  /// upload deletes the row, so the table only ever holds live problems.
  static const String _createUploadFailures =
      '''
CREATE TABLE $uploadFailuresTable (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  reason TEXT NOT NULL,
  message TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  automatic INTEGER NOT NULL,
  failed_at TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
)
''';

  /// One row per chunked upload the server has part-received. `temp_file_id`
  /// and `upload_session_id` together address that half-written file; neither
  /// can be recomputed, so losing the row means re-sending the whole file.
  /// `file_size` guards against appending to bytes that belong to a
  /// different file after the asset changed. The row is deleted once the
  /// upload commits, so the table only holds uploads still in flight.
  static const String _createUploadResumptions =
      '''
CREATE TABLE $uploadResumptionsTable (
  account_key TEXT NOT NULL,
  local_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  upload_session_id TEXT NOT NULL,
  temp_file_id TEXT NOT NULL,
  PRIMARY KEY (account_key, local_id)
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
    if (from < 5) {
      // v5 removed the template's bookmarks sample feature; schemas 1–4
      // created its table in `_create`, so an upgrading device drops it
      // here. IF EXISTS keeps the step idempotent.
      await db.execute('DROP TABLE IF EXISTS bookmarks');
    }
    if (from < 6) {
      await db.execute(_createBackupNotifications);
    }
    if (from < 7) {
      await db.execute(_createAlbumSnapshots);
    }
    if (from < 8) {
      await db.execute(_createUploadFailures);
    }
    if (from < 9) {
      await db.execute(_createUploadResumptions);
    }
  }
}
