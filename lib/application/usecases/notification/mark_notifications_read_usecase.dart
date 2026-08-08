import 'package:flutterbase/domain/repositories/backup_notification_repository.dart';

/// Marks every notification as seen. The list screen calls this on open.
final class MarkNotificationsReadUseCase {
  const MarkNotificationsReadUseCase(this._notifications);

  final BackupNotificationRepository _notifications;

  Future<void> execute() => _notifications.markAllRead();
}
