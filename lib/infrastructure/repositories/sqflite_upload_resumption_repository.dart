import 'package:photonest/domain/entities/upload_resumption.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/upload_resumption_repository.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [UploadResumptionRepository] backed by SQLite, scoped to the signed-in
/// account.
///
/// In the database rather than in memory because the interruption worth
/// surviving is the process ending: a background backup pass can be killed
/// mid-video, and an in-memory note would die with it — which is exactly
/// the case that used to cost a whole re-upload.
final class SqfliteUploadResumptionRepository
    implements UploadResumptionRepository {
  SqfliteUploadResumptionRepository(
    this._database,
    this._sessions,
    this._endpoints,
  );

  final Database _database;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;

  @override
  Future<UploadResumption?> find(String localId) async {
    final account = _activeAccountKey();
    if (account == null) return null;
    try {
      final rows = await _database.query(
        AppDatabase.uploadResumptionsTable,
        where: 'account_key = ? AND local_id = ?',
        whereArgs: [account, localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _resumptionFrom(rows.first);
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the resume point for $localId.',
        cause: error,
      );
    }
  }

  @override
  Future<void> save(UploadResumption resumption) async {
    final account = _activeAccountKey();
    // Uploads only happen signed in; a record under a shared key would send
    // one account's temp file id to another server.
    if (account == null) return;
    try {
      await _database.insert(
        AppDatabase.uploadResumptionsTable,
        {
          'account_key': account,
          'local_id': resumption.localId,
          'file_name': resumption.fileName,
          'file_size': resumption.fileSize,
          'upload_session_id': resumption.uploadSessionId,
          'temp_file_id': resumption.tempFileId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not record the resume point for ${resumption.fileName}.',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear(String localId, {required String tempFileId}) async {
    final account = _activeAccountKey();
    if (account == null) return;
    try {
      await _database.delete(
        AppDatabase.uploadResumptionsTable,
        // The temp file id is part of the condition, not just the key: a row
        // that now belongs to an overlapping upload of the same photo is not
        // ours to delete.
        where: 'account_key = ? AND local_id = ? AND temp_file_id = ?',
        whereArgs: [account, localId, tempFileId],
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not clear the resume point for $localId.',
        cause: error,
      );
    }
  }

  static UploadResumption _resumptionFrom(Map<String, Object?> row) {
    return UploadResumption(
      localId: row['local_id']! as String,
      fileName: row['file_name']! as String,
      fileSize: row['file_size']! as int,
      uploadSessionId: row['upload_session_id']! as String,
      tempFileId: row['temp_file_id']! as String,
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
