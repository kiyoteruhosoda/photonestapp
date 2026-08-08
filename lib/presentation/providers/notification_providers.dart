import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/notification/get_unread_notification_count_usecase.dart';
import 'package:flutterbase/application/usecases/notification/list_backup_notifications_usecase.dart';
import 'package:flutterbase/application/usecases/notification/mark_notifications_read_usecase.dart';
import 'package:flutterbase/application/usecases/notification/watch_backup_notifications_usecase.dart';
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

final Provider<WatchBackupNotificationsUseCase>
watchBackupNotificationsUseCaseProvider =
    Provider<WatchBackupNotificationsUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('watchBackupNotificationsUseCaseProvider'),
      );
    });

// ─── Screen state ──────────────────────────────────────────────────────────

/// Unread notifications, for the badge on the header's bell button.
final AsyncNotifierProvider<UnreadNotificationCountNotifier, int>
unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadNotificationCountNotifier, int>(
      UnreadNotificationCountNotifier.new,
    );

/// Keeps the unread count live while the app runs.
///
/// Re-reads whenever this isolate mutates the notification store — a
/// foreground sync pass recording a result, or the list marking loaded
/// ids read — so the bell reflects a backup the moment it finishes.
/// Writes from the background isolate surface on the next app start.
class UnreadNotificationCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    final subscription = ref
        .read(watchBackupNotificationsUseCaseProvider)
        .execute()
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(subscription.cancel);
    return ref.read(getUnreadNotificationCountUseCaseProvider).execute();
  }
}

/// The notification list, newest first.
///
/// autoDispose on purpose: every visit to the screen is a fresh read. The
/// first visit loads entities that are still unread (rendered bold) and
/// then marks exactly those ids seen; the next visit re-queries and gets
/// them back as read, so the bold styling does not stick across visits.
final AsyncNotifierProvider<
  BackupNotificationsNotifier,
  List<BackupNotification>
>
backupNotificationsProvider =
    AsyncNotifierProvider.autoDispose<
      BackupNotificationsNotifier,
      List<BackupNotification>
    >(BackupNotificationsNotifier.new);

/// Loads the notifications and marks the loaded ones as seen.
class BackupNotificationsNotifier
    extends AsyncNotifier<List<BackupNotification>> {
  @override
  Future<List<BackupNotification>> build() async {
    final notifications = await ref
        .read(listBackupNotificationsUseCaseProvider)
        .execute();
    // Mark read *after* a successful load — a list that failed to render
    // informed nobody — and only what was actually loaded: a result
    // recorded while the list is open stays unread until it is seen. The
    // badge hears about the write through the change stream.
    final unreadIds = [
      for (final notification in notifications)
        if (!notification.isRead) notification.id,
    ];
    await ref.read(markNotificationsReadUseCaseProvider).execute(unreadIds);
    return notifications;
  }

  /// Re-reads the list, e.g. from the error state's retry button.
  Future<void> reload() async {
    state = const AsyncValue<List<BackupNotification>>.loading();
    state = await AsyncValue.guard(build);
  }
}
