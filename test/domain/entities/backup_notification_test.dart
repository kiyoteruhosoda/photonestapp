import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/backup_notification.dart';
import 'package:photonest/domain/errors/app_error.dart';

void main() {
  BackupNotification build({
    int id = 1,
    int uploadedCount = 3,
    int failedCount = 1,
    DateTime? occurredAt,
    bool isRead = false,
  }) {
    return BackupNotification(
      id: id,
      uploadedCount: uploadedCount,
      failedCount: failedCount,
      occurredAt: occurredAt ?? DateTime.utc(2026, 8, 8, 9, 30),
      isRead: isRead,
    );
  }

  group('BackupNotification', () {
    test('rejects negative counts', () {
      expect(() => build(uploadedCount: -1), throwsA(isA<DomainError>()));
      expect(() => build(failedCount: -1), throwsA(isA<DomainError>()));
    });

    test('rejects a pass that attempted nothing', () {
      // A notification for "nothing happened" would train the user to
      // ignore the list.
      expect(
        () => build(uploadedCount: 0, failedCount: 0),
        throwsA(isA<DomainError>()),
      );
    });

    test('normalises the occurrence instant to UTC', () {
      final local = DateTime(2026, 8, 8, 18, 30);
      expect(build(occurredAt: local).occurredAt.isUtc, isTrue);
      expect(build(occurredAt: local).occurredAt, local.toUtc());
    });

    test('hasFailures answers from the failed count', () {
      expect(build(failedCount: 0).hasFailures, isFalse);
      expect(build(failedCount: 2).hasFailures, isTrue);
    });

    test('identity is the id, not the counts', () {
      expect(build(uploadedCount: 1), build(uploadedCount: 9));
      expect(build(id: 1), isNot(build(id: 2)));
      expect(build().hashCode, build().hashCode);
    });

    test('toString names id and counts', () {
      expect(
        build().toString(),
        'BackupNotification(1, +3/-1 at 2026-08-08 09:30:00.000Z)',
      );
    });
  });
}
