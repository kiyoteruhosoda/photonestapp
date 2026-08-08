import 'dart:async';

import 'package:flutterbase/domain/entities/backup_notification.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/backup_notification_repository.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [BackupNotificationRepository] backed by the shared SQLite database.
///
/// The table is shared by the foreground app and the background WorkManager
/// engine — both isolates open the same file — so a pass run while the app
/// was closed is visible the next time the list opens.
final class SqfliteBackupNotificationRepository
    implements BackupNotificationRepository {
  SqfliteBackupNotificationRepository(this._database);

  final Database _database;

  /// Broadcast so the badge and any future listener can subscribe at once.
  /// Never closed: the repository lives as long as the app process.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<BackupNotification>> findAll() async {
    try {
      final rows = await _database.query(
        AppDatabase.backupNotificationsTable,
        orderBy: 'id DESC',
      );
      return rows.map(_notificationFrom).toList();
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the backup notifications.',
        cause: error,
      );
    }
  }

  @override
  Future<BackupNotification> add({
    required int uploadedCount,
    required int failedCount,
    required DateTime occurredAt,
  }) async {
    try {
      final id = await _database
          .insert(AppDatabase.backupNotificationsTable, <String, Object?>{
            'uploaded_count': uploadedCount,
            'failed_count': failedCount,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'read': 0,
          });
      _changes.add(null);
      return BackupNotification(
        id: id,
        uploadedCount: uploadedCount,
        failedCount: failedCount,
        occurredAt: occurredAt,
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not store the backup notification.',
        cause: error,
      );
    }
  }

  @override
  Future<int> unreadCount() async {
    try {
      final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS unread '
        'FROM ${AppDatabase.backupNotificationsTable} WHERE read = 0',
      );
      return rows.first['unread']! as int;
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not count the unread notifications.',
        cause: error,
      );
    }
  }

  @override
  Future<void> markRead(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final placeholders = List.filled(ids.length, '?').join(', ');
      await _database.update(
        AppDatabase.backupNotificationsTable,
        {'read': 1},
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      _changes.add(null);
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not mark the notifications as read.',
        cause: error,
      );
    }
  }

  static BackupNotification _notificationFrom(Map<String, Object?> row) {
    return BackupNotification(
      id: row['id']! as int,
      uploadedCount: row['uploaded_count']! as int,
      failedCount: row['failed_count']! as int,
      occurredAt: DateTime.parse(row['occurred_at']! as String).toUtc(),
      isRead: row['read'] == 1,
    );
  }
}
