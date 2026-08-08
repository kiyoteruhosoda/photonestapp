import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/notification/get_unread_notification_count_usecase.dart';
import 'package:flutterbase/application/usecases/notification/list_backup_notifications_usecase.dart';
import 'package:flutterbase/application/usecases/notification/mark_notifications_read_usecase.dart';
import 'package:flutterbase/domain/entities/backup_notification.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, overridden by the composition root.

final Provider<ListBackupNotificationsUseCase>
listBackupNotificationsUseCaseProvider =
    Provider<ListBackupNotificationsUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listBackupNotificationsUseCaseProvider'),
      );
    });

final Provider<GetUnreadNotificationCountUseCase>
getUnreadNotificationCountUseCaseProvider =
    Provider<GetUnreadNotificationCountUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getUnreadNotificationCountUseCaseProvider'),
      );
    });

final Provider<MarkNotificationsReadUseCase>
markNotificationsReadUseCaseProvider = Provider<MarkNotificationsReadUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('markNotificationsReadUseCaseProvider'),
  );
});

// ─── Screen state ──────────────────────────────────────────────────────────

/// Unread notifications, for the badge on the header's bell button.
///
/// Read at startup and invalidated whenever the notification list marks
/// everything read, so the badge disappears the moment the list is seen.
final FutureProvider<int> unreadNotificationCountProvider = FutureProvider<int>(
  (ref) => ref.read(getUnreadNotificationCountUseCaseProvider).execute(),
);

/// The notification list, newest first.
///
/// Opening the screen marks everything as read: showing the list *is*
/// reading it, and the badge should not keep pointing at what the user has
/// already seen.
final AsyncNotifierProvider<
  BackupNotificationsNotifier,
  List<BackupNotification>
>
backupNotificationsProvider =
    AsyncNotifierProvider<
      BackupNotificationsNotifier,
      List<BackupNotification>
    >(BackupNotificationsNotifier.new);

/// Loads the notifications and clears the unread badge.
class BackupNotificationsNotifier
    extends AsyncNotifier<List<BackupNotification>> {
  @override
  Future<List<BackupNotification>> build() async {
    final notifications = await ref
        .read(listBackupNotificationsUseCaseProvider)
        .execute();
    // Mark read *after* a successful load: a list that failed to render did
    // not inform anybody, so the badge must survive for the retry.
    await ref.read(markNotificationsReadUseCaseProvider).execute();
    ref.invalidate(unreadNotificationCountProvider);
    return notifications;
  }

  /// Re-reads the list, e.g. from the error state's retry button.
  Future<void> reload() async {
    state = const AsyncValue<List<BackupNotification>>.loading();
    state = await AsyncValue.guard(build);
  }
}
