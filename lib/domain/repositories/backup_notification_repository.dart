import 'package:flutterbase/domain/entities/backup_notification.dart';

/// Stores backup notifications on this device.
///
/// Device-scoped on purpose: a notification reports what this device's
/// backup did, which stays true after signing into another account.
/// Implementations live in Infrastructure and assign the ids.
abstract interface class BackupNotificationRepository {
  /// All notifications, newest first.
  Future<List<BackupNotification>> findAll();

  /// Records the outcome of one backup pass and returns it with its id.
  ///
  /// [occurredAt] is the pass's finish instant in UTC; callers pass it in so
  /// the domain never reads the wall clock.
  Future<BackupNotification> add({
    required int uploadedCount,
    required int failedCount,
    required DateTime occurredAt,
  });

  /// How many notifications the user has not seen yet.
  Future<int> unreadCount();

  /// Marks every notification as seen. Opening the list calls this.
  Future<void> markAllRead();
}
