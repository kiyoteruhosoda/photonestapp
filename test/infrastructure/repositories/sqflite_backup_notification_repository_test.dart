import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_backup_notification_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteBackupNotificationRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SqfliteBackupNotificationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final occurredAt = DateTime.utc(2026, 8, 8, 9, 30);

  test('add assigns ids and findAll answers newest first', () async {
    final first = await repository.add(
      uploadedCount: 3,
      failedCount: 0,
      occurredAt: occurredAt,
    );
    final second = await repository.add(
      uploadedCount: 1,
      failedCount: 2,
      occurredAt: occurredAt.add(const Duration(minutes: 5)),
    );
    expect(second.id, greaterThan(first.id));

    final all = await repository.findAll();
    expect(all.map((n) => n.id).toList(), [second.id, first.id]);
    expect(all.first.uploadedCount, 1);
    expect(all.first.failedCount, 2);
    expect(all.first.hasFailures, isTrue);
    expect(all.first.occurredAt.isUtc, isTrue);
  });

  test('notifications arrive unread; markAllRead clears the count', () async {
    await repository.add(
      uploadedCount: 1,
      failedCount: 0,
      occurredAt: occurredAt,
    );
    await repository.add(
      uploadedCount: 2,
      failedCount: 0,
      occurredAt: occurredAt,
    );
    expect(await repository.unreadCount(), 2);

    await repository.markAllRead();

    expect(await repository.unreadCount(), 0);
    final all = await repository.findAll();
    expect(all.every((n) => n.isRead), isTrue);
  });

  test('a notification recorded after markAllRead is unread again', () async {
    await repository.add(
      uploadedCount: 1,
      failedCount: 0,
      occurredAt: occurredAt,
    );
    await repository.markAllRead();

    await repository.add(
      uploadedCount: 4,
      failedCount: 1,
      occurredAt: occurredAt,
    );

    expect(await repository.unreadCount(), 1);
  });
}
