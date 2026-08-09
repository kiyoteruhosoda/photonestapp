import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/sync_lease_repository.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [SyncLeaseRepository] backed by the shared SQLite database.
///
/// Both isolates open the same database file, and sqflite transactions run
/// as `BEGIN IMMEDIATE` — SQLite's file lock serialises them, which is what
/// makes check-then-write below atomic across isolates, not just within
/// one.
final class SqfliteSyncLeaseRepository implements SyncLeaseRepository {
  const SqfliteSyncLeaseRepository(this._database);

  /// Name of the one lease this app uses today.
  static const String leaseName = 'auto-upload-sync';

  final Database _database;

  @override
  Future<bool> tryAcquire(
    String holder, {
    required DateTime until,
    required DateTime now,
  }) async {
    try {
      return await _database.transaction((txn) async {
        final rows = await txn.query(
          AppDatabase.syncLeasesTable,
          where: 'name = ?',
          whereArgs: [leaseName],
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          final expires = DateTime.tryParse(row['expires_at']! as String);
          final live = expires != null && expires.isAfter(now.toUtc());
          if (live && row['holder'] != holder) return false;
        }
        await txn.insert(
          AppDatabase.syncLeasesTable,
          {
            'name': leaseName,
            'holder': holder,
            'expires_at': until.toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      });
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not acquire the sync lease.',
        cause: error,
      );
    }
  }

  @override
  Future<void> release(String holder) async {
    try {
      await _database.delete(
        AppDatabase.syncLeasesTable,
        where: 'name = ? AND holder = ?',
        whereArgs: [leaseName, holder],
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not release the sync lease.',
        cause: error,
      );
    }
  }
}
