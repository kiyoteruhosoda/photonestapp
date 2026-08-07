import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [UploadHistoryRepository] backed by SQLite.
///
/// The history exists to keep automatic upload idempotent, so it lives in
/// the database rather than preferences: it grows with the photo library
/// and must survive as reliably as the bookmarks do.
final class SqfliteUploadHistoryRepository implements UploadHistoryRepository {
  const SqfliteUploadHistoryRepository(this._database);

  final Database _database;

  @override
  Future<Set<String>> uploadedLocalIds() async {
    try {
      final rows = await _database.query(
        AppDatabase.uploadedPhotosTable,
        columns: ['local_id'],
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
    try {
      await _database.insert(
        AppDatabase.uploadedPhotosTable,
        {
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
}
