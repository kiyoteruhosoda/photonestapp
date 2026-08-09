import 'dart:async';

import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/entities/upload_failure.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/upload_failure_repository.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [UploadFailureRepository] backed by SQLite, scoped to the signed-in
/// account.
///
/// In the database rather than in memory on purpose: the whole point of the
/// record is that it outlives the run that produced it, so a photo that
/// failed in a background pass last night is still nameable this morning.
/// Keyed by server + account like the upload history — the same photo can
/// be fine for one server and rejected by another.
final class SqfliteUploadFailureRepository implements UploadFailureRepository {
  SqfliteUploadFailureRepository(
    this._database,
    this._sessions,
    this._endpoints,
  );

  final Database _database;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;

  // Deliberately never closed: the repository lives as long as the app, and
  // the background isolate's copy dies with its engine.
  // ignore: close_sinks
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<UploadFailure>> list() async {
    final account = _activeAccountKey();
    if (account == null) return const <UploadFailure>[];
    try {
      final rows = await _database.query(
        AppDatabase.uploadFailuresTable,
        where: 'account_key = ?',
        whereArgs: [account],
        orderBy: 'failed_at DESC',
      );
      return rows.map(_failureFrom).toList();
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the upload failures.',
        cause: error,
      );
    }
  }

  @override
  Future<void> record({
    required LocalPhoto photo,
    required UploadFailureReason reason,
    required String message,
    required bool automatic,
    required DateTime failedAt,
  }) async {
    final account = _activeAccountKey();
    // Uploads only happen signed in; recording under a shared key would
    // show one account's problems to another.
    if (account == null) return;
    try {
      // The insert and the attempt count have to agree, so the read and the
      // write share a transaction: two isolates failing the same photo at
      // once must not both write "attempt 1".
      await _database.transaction((txn) async {
        final existing = await txn.query(
          AppDatabase.uploadFailuresTable,
          columns: ['attempts'],
          where: 'account_key = ? AND local_id = ?',
          whereArgs: [account, photo.localId],
        );
        final attempts = existing.isEmpty
            ? 1
            : (existing.first['attempts']! as int) + 1;
        await txn.insert(
          AppDatabase.uploadFailuresTable,
          {
            'account_key': account,
            'local_id': photo.localId,
            'file_name': photo.fileName,
            'reason': reason.name,
            'message': message,
            'attempts': attempts,
            'automatic': automatic ? 1 : 0,
            'failed_at': failedAt.toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      _changes.add(null);
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not record the failure of ${photo.fileName}.',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear(String localId) async {
    final account = _activeAccountKey();
    if (account == null) return;
    await _delete('account_key = ? AND local_id = ?', [account, localId]);
  }

  @override
  Future<void> clearAll() async {
    final account = _activeAccountKey();
    if (account == null) return;
    await _delete('account_key = ?', [account]);
  }

  Future<void> _delete(String where, List<Object?> whereArgs) async {
    try {
      final removed = await _database.delete(
        AppDatabase.uploadFailuresTable,
        where: where,
        whereArgs: whereArgs,
      );
      // Only announce a real change: a success for a photo that was never
      // failing is the common case, and rebuilding the list for it would be
      // pure noise.
      if (removed > 0) _changes.add(null);
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not clear the upload failures.',
        cause: error,
      );
    }
  }

  static UploadFailure _failureFrom(Map<String, Object?> row) {
    return UploadFailure(
      photo: LocalPhoto(
        localId: row['local_id']! as String,
        fileName: row['file_name']! as String,
        // The record is about the upload, not the capture: the row keeps no
        // capture instant, and the attempt's own time is what the list
        // shows.
        takenAt: DateTime.parse(row['failed_at']! as String).toUtc(),
      ),
      reason: _reasonFrom(row['reason']! as String),
      message: row['message']! as String,
      attempts: row['attempts']! as int,
      automatic: (row['automatic']! as int) != 0,
      failedAt: DateTime.parse(row['failed_at']! as String).toUtc(),
    );
  }

  /// A reason this build does not know about reads as [rejected] rather
  /// than crashing the list — a downgrade must not make the screen
  /// unopenable.
  static UploadFailureReason _reasonFrom(String name) {
    return UploadFailureReason.values.firstWhere(
      (reason) => reason.name == name,
      orElse: () => UploadFailureReason.rejected,
    );
  }

  /// `server#email`, or null while signed out.
  String? _activeAccountKey() {
    final session = _sessions.load();
    if (session == null) return null;
    final endpoint = _endpoints.load();
    return '${endpoint ?? ''}#${session.email}';
  }
}
