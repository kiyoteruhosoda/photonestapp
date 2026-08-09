import 'package:photonest/domain/entities/backup_notification.dart';

/// Stores backup notifications on this device.
///
/// Device-scoped on purpose: a notification reports what this device's
/// backup did, which stays true after signing into another account.
/// Implementations live in Infrastructure and assign the ids.
abstract interface class BackupNotificationRepository {
  /// Emits after every mutation this isolate makes — an add or a mark-read —
  /// so a live badge can re-read the unread count. Writes from the other
  /// isolate (the background WorkManager engine) are not observable here;
  /// they are picked up on the next cold read.
  Stream<void> get changes;

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

  /// Marks the given notifications as seen.
  ///
  /// Only ids the reader actually loaded belong here: a blanket "mark
  /// everything" would also swallow results recorded after the list was
  /// read, before the user ever saw them.
  Future<void> markRead(List<int> ids);
}
