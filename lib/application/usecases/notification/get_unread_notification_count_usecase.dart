import 'package:photonest/domain/repositories/backup_notification_repository.dart';

/// Counts the notifications the user has not seen yet, for the header badge.
final class GetUnreadNotificationCountUseCase {
  const GetUnreadNotificationCountUseCase(this._notifications);

  final BackupNotificationRepository _notifications;

  Future<int> execute() => _notifications.unreadCount();
}
