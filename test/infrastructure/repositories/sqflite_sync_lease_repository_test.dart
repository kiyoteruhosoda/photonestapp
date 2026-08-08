import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_sync_lease_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteSyncLeaseRepository repository;

  final now = DateTime.utc(2026, 8, 8, 12);
  final until = now.add(const Duration(minutes: 30));

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SqfliteSyncLeaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('a free lease is granted', () async {
    expect(
      await repository.tryAcquire('foreground', until: until, now: now),
      isTrue,
    );
  });

  test('a live lease refuses another holder', () async {
    await repository.tryAcquire('foreground', until: until, now: now);

    expect(
      await repository.tryAcquire('background', until: until, now: now),
      isFalse,
    );
  });

  test('the current holder may re-acquire (extend) its own lease', () async {
    await repository.tryAcquire('foreground', until: until, now: now);

    expect(
      await repository.tryAcquire('foreground', until: until, now: now),
      isTrue,
    );
  });

  test('an expired lease is taken over', () async {
    await repository.tryAcquire('foreground', until: until, now: now);

    final later = until.add(const Duration(seconds: 1));
    expect(
      await repository.tryAcquire(
        'background',
        until: later.add(const Duration(minutes: 30)),
        now: later,
      ),
      isTrue,
    );
  });

  test('release frees the lease for the next holder', () async {
    await repository.tryAcquire('foreground', until: until, now: now);
    await repository.release('foreground');

    expect(
      await repository.tryAcquire('background', until: until, now: now),
      isTrue,
    );
  });

  test('release by a non-holder leaves the lease in place', () async {
    await repository.tryAcquire('foreground', until: until, now: now);
    await repository.release('background');

    expect(
      await repository.tryAcquire('background', until: until, now: now),
      isFalse,
    );
  });
}
