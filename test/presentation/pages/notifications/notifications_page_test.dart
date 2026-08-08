import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/notifications/notifications_page.dart';
import 'package:flutterbase/presentation/providers/notification_providers.dart';
import 'package:flutterbase/presentation/widgets/ui/app_state_views.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  testWidgets('renders the empty state when nothing was recorded', (
    tester,
  ) async {
    await pumpInScope(tester, const NotificationsPage());
    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.textContaining(l10n.notificationsEmpty), findsOneWidget);
  });

  testWidgets('lists results newest first with per-outcome wording', (
    tester,
  ) async {
    final scope = TestScope(
      notificationRepository: FakeBackupNotificationRepository([
        testBackupNotification(id: 1, uploadedCount: 3),
        testBackupNotification(id: 2, uploadedCount: 1, failedCount: 2),
      ]),
    );
    await pumpInScope(tester, const NotificationsPage(), scope: scope);

    // Newest (id 2, with failures) above oldest (id 1, clean).
    final failure = tester.getTopLeft(
      find.text(l10n.notificationBackupHadFailures),
    );
    final success = tester.getTopLeft(
      find.text(l10n.notificationBackupCompleted),
    );
    expect(failure.dy, lessThan(success.dy));
    expect(find.textContaining(l10n.uploadDone(3)), findsOneWidget);
    expect(find.textContaining(l10n.uploadFailed(2)), findsOneWidget);
  });

  testWidgets('opening the list marks the loaded notifications read', (
    tester,
  ) async {
    final repository = FakeBackupNotificationRepository([
      testBackupNotification(id: 1),
    ]);
    final scope = TestScope(notificationRepository: repository);

    await pumpInScope(tester, const NotificationsPage(), scope: scope);

    expect(repository.markReadCalls, [
      [1],
    ]);
    expect(await repository.unreadCount(), 0);
    // The badge provider sees the same store.
    expect(
      await scope.container.read(unreadNotificationCountProvider.future),
      0,
    );
  });

  testWidgets('a result recorded while the list is open stays unread', (
    tester,
  ) async {
    final repository = FakeBackupNotificationRepository([
      testBackupNotification(id: 1),
    ]);
    final scope = TestScope(notificationRepository: repository);
    await pumpInScope(tester, const NotificationsPage(), scope: scope);

    // A foreground sync pass finishes while the user is looking at the
    // already-loaded list — its result has not been seen.
    await repository.add(
      uploadedCount: 2,
      failedCount: 0,
      occurredAt: testNotificationOccurredAt,
    );
    await tester.pumpAndSettle();

    expect(await repository.unreadCount(), 1);
    expect(
      await scope.container.read(unreadNotificationCountProvider.future),
      1,
    );
  });

  testWidgets('a load failure shows the error state with a retry', (
    tester,
  ) async {
    final repository = FakeBackupNotificationRepository([
      testBackupNotification(id: 1),
    ])..failure = const InfrastructureError('storage unavailable');
    final scope = TestScope(notificationRepository: repository);

    await pumpInScope(tester, const NotificationsPage(), scope: scope);
    expect(find.byType(AppErrorView), findsOneWidget);
    // A list that never rendered informed nobody — everything stays unread.
    expect(repository.markReadCalls, isEmpty);

    repository.failure = null;
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.notificationBackupCompleted), findsOneWidget);
    expect(repository.markReadCalls, [
      [1],
    ]);
  });
}
