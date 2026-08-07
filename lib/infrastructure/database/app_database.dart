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
  static const int schemaVersion = 1;

  /// Table holding the bookmarks sample feature.
  static const String bookmarksTable = 'bookmarks';

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
  }

  /// Applies the migrations between two schema versions.
  ///
  /// Written as a fall-through ladder — `if (from < 2) { … }`, then
  /// `if (from < 3) { … }` — so upgrading across several releases at once
  /// runs each step in order. Version 1 is the initial schema, so there is
  /// nothing to apply yet.
  static Future<void> _upgrade(Database db, int from, int to) async {
    // if (from < 2) {
    //   await db.execute('ALTER TABLE $bookmarksTable ADD COLUMN note TEXT');
    // }
  }
}
