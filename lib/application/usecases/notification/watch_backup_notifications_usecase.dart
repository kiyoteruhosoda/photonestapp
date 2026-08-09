import 'package:photonest/domain/repositories/backup_notification_repository.dart';

/// Signals whenever this isolate mutates the notification store.
///
/// The header's unread badge listens to this: a foreground sync pass that
/// records a result pokes the stream, and the badge re-reads its count
/// without waiting for the next app start. Background-isolate writes are
/// invisible to this stream and surface on the next cold read instead.
final class WatchBackupNotificationsUseCase {
  const WatchBackupNotificationsUseCase(this._notifications);

  final BackupNotificationRepository _notifications;

  Stream<void> execute() => _notifications.changes;
}
