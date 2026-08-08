import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/notification/get_unread_notification_count_usecase.dart';
import 'package:flutterbase/application/usecases/notification/list_backup_notifications_usecase.dart';
import 'package:flutterbase/application/usecases/notification/mark_notifications_read_usecase.dart';
import 'package:flutterbase/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeBackupNotificationRepository notifications;
  late RecordingAppLogger logger;

  setUp(() {
    notifications = FakeBackupNotificationRepository();
    logger = RecordingAppLogger();
  });

  group('RecordBackupResultUseCase', () {
    RecordBackupResultUseCase useCase() =>
        RecordBackupResultUseCase(notifications, logger);

    test('stores a notification for a pass that attempted uploads', () async {
      await useCase().execute(uploadedCount: 3, failedCount: 1);

      final stored = notifications.stored.single;
      expect(stored.uploadedCount, 3);
      expect(stored.failedCount, 1);
      expect(stored.occurredAt.isUtc, isTrue);
      expect(stored.isRead, isFalse);
      expect(
        logger.messagesAt(LogLevel.info),
        contains(contains('backup result recorded')),
      );
    });

    test('a pass that moved nothing stays silent', () async {
      await useCase().execute(uploadedCount: 0, failedCount: 0);
      expect(notifications.stored, isEmpty);
    });

    test('a storage failure is logged, not rethrown', () async {
      // The uploads themselves succeeded; failing the sync pass over a
      // missing notification row would be worse than missing the row.
      notifications.failure = const InfrastructureError('disk full');

      await useCase().execute(uploadedCount: 1, failedCount: 0);

      expect(
        logger.messagesAt(LogLevel.warning),
        contains(contains('could not record backup result')),
      );
    });
  });

  group('ListBackupNotificationsUseCase', () {
    test('answers newest first', () async {
      notifications = FakeBackupNotificationRepository([
        testBackupNotification(id: 1),
        testBackupNotification(id: 2),
      ]);

      final all = await ListBackupNotificationsUseCase(notifications).execute();

      expect(all.map((n) => n.id).toList(), [2, 1]);
    });
  });

  group('GetUnreadNotificationCountUseCase', () {
    test('counts only the unseen notifications', () async {
      notifications = FakeBackupNotificationRepository([
        testBackupNotification(id: 1, isRead: true),
        testBackupNotification(id: 2),
        testBackupNotification(id: 3),
      ]);

      final unread = await GetUnreadNotificationCountUseCase(
        notifications,
      ).execute();

      expect(unread, 2);
    });
  });

  group('MarkNotificationsReadUseCase', () {
    test('marks everything as seen', () async {
      notifications = FakeBackupNotificationRepository([
        testBackupNotification(id: 1),
        testBackupNotification(id: 2),
      ]);

      await MarkNotificationsReadUseCase(notifications).execute();

      expect(notifications.stored.every((n) => n.isRead), isTrue);
      expect(notifications.markAllReadCalls, 1);
    });
  });
}
