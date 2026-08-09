import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/upload_history_repository.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [UploadHistoryRepository] backed by SQLite, scoped to the signed-in
/// account.
///
/// The history exists to keep automatic upload idempotent, so it lives in
/// the database rather than preferences: it grows with the photo library
/// and preferences offer no durable, queryable storage. Rows are keyed by
/// server + account as well as photo id — a photo uploaded to account A
/// still counts as pending after signing into account B.
final class SqfliteUploadHistoryRepository implements UploadHistoryRepository {
  const SqfliteUploadHistoryRepository(
    this._database,
    this._sessions,
    this._endpoints,
  );

  final Database _database;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;

  @override
  Future<Set<String>> uploadedLocalIds() async {
    final account = _activeAccountKey();
    // Signed out means no destination, and with no destination nothing
    // counts as "already uploaded".
    if (account == null) return const <String>{};
    try {
      final rows = await _database.query(
        AppDatabase.uploadedPhotosTable,
        columns: ['local_id'],
        where: 'account_key = ?',
        whereArgs: [account],
      );
      return rows.map((row) => row['local_id']! as String).toSet();
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the upload history.',
        cause: error,
      );
    }
  }

  @override
  Future<void> markUploaded(LocalPhoto photo, DateTime uploadedAt) async {
    final account = _activeAccountKey();
    if (account == null) {
      // Uploads only happen signed in, so this is a programming error — but
      // recording under a shared key would poison another account's history.
      throw const AuthenticationError(
        'Cannot record an upload while signed out.',
      );
    }
    try {
      await _database.insert(
        AppDatabase.uploadedPhotosTable,
        {
          'account_key': account,
          'local_id': photo.localId,
          'file_name': photo.fileName,
          'uploaded_at': uploadedAt.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not record the upload of ${photo.fileName}.',
        cause: error,
      );
    }
  }

  /// `server#email`, or null while signed out.
  String? _activeAccountKey() {
    final session = _sessions.load();
    if (session == null) return null;
    final endpoint = _endpoints.load();
    return '${endpoint ?? ''}#${session.email}';
  }
}
