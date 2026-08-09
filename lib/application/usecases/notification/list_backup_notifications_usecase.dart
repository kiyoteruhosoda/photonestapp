import 'package:photonest/domain/entities/backup_notification.dart';
import 'package:photonest/domain/repositories/backup_notification_repository.dart';

/// Loads every backup notification, newest first.
final class ListBackupNotificationsUseCase {
  const ListBackupNotificationsUseCase(this._notifications);

  final BackupNotificationRepository _notifications;

  Future<List<BackupNotification>> execute() => _notifications.findAll();
}
