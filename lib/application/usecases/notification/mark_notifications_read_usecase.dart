import 'package:photonest/domain/repositories/backup_notification_repository.dart';

/// Marks the given notifications as seen.
///
/// The list screen calls this with the ids it actually rendered — never
/// with "everything" — so a result recorded while the list was open stays
/// unread until the user has really seen it.
final class MarkNotificationsReadUseCase {
  const MarkNotificationsReadUseCase(this._notifications);

  final BackupNotificationRepository _notifications;

  Future<void> execute(List<int> ids) async {
    if (ids.isEmpty) return;
    await _notifications.markRead(ids);
  }
}
