import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/backup_notification_repository.dart';

/// Records the outcome of one backup pass as a notification.
///
/// Called by the sync pass in both isolates — the foreground app and the
/// background WorkManager engine — so a backup that ran while the app was
/// closed still shows up in the list.
final class RecordBackupResultUseCase {
  const RecordBackupResultUseCase(this._notifications, this._logger);

  final BackupNotificationRepository _notifications;
  final AppLogger _logger;

  /// Stores a notification for a pass that attempted at least one upload.
  ///
  /// A pass that moved nothing is silent: waking the user for "nothing
  /// happened" would train them to ignore the list.
  ///
  /// Storage failures are logged and swallowed on purpose — the uploads
  /// themselves succeeded, and failing the whole sync pass over a missing
  /// notification row would be worse than missing the notification.
  Future<void> execute({
    required int uploadedCount,
    required int failedCount,
  }) async {
    if (uploadedCount == 0 && failedCount == 0) return;
    try {
      await _notifications.add(
        uploadedCount: uploadedCount,
        failedCount: failedCount,
        occurredAt: DateTime.now().toUtc(),
      );
      _logger.info(
        '[Notification] backup result recorded '
        '($uploadedCount uploaded, $failedCount failed)',
      );
    } on AppError catch (error) {
      _logger.warning('[Notification] could not record backup result: $error');
    }
  }
}
