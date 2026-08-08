import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/entities/upload_failure.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_upload_failure_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fakes.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late FakeSessionRepository sessions;
  late FakeApiEndpointRepository endpoints;
  late SqfliteUploadFailureRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
    repository = SqfliteUploadFailureRepository(db, sessions, endpoints);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> record(
    String localId, {
    UploadFailureReason reason = UploadFailureReason.rejected,
    bool automatic = false,
    DateTime? at,
  }) {
    return repository.record(
      photo: testLocalPhoto(localId: localId, fileName: '$localId.jpg'),
      reason: reason,
      message: 'the server said no',
      automatic: automatic,
      failedAt: at ?? DateTime.utc(2026, 8, 8, 10),
    );
  }

  test('starts empty', () async {
    expect(await repository.list(), isEmpty);
  });

  test('a recorded failure round-trips with its reason and origin', () async {
    await record(
      'a',
      reason: UploadFailureReason.unsupportedFormat,
      automatic: true,
    );

    final stored = (await repository.list()).single;
    expect(stored.photo.localId, 'a');
    expect(stored.photo.fileName, 'a.jpg');
    expect(stored.reason, UploadFailureReason.unsupportedFormat);
    expect(stored.message, 'the server said no');
    expect(stored.automatic, isTrue);
    expect(stored.attempts, 1);
    expect(stored.failedAt, DateTime.utc(2026, 8, 8, 10));
  });

  test('recording the same photo again counts the attempt', () async {
    await record('a');
    await record('a', at: DateTime.utc(2026, 8, 8, 11));

    final stored = (await repository.list()).single;
    expect(stored.attempts, 2);
    expect(stored.failedAt, DateTime.utc(2026, 8, 8, 11));
  });

  test('the newest attempt comes first', () async {
    await record('a', at: DateTime.utc(2026, 8, 8, 9));
    await record('b', at: DateTime.utc(2026, 8, 8, 11));

    expect((await repository.list()).map((failure) => failure.photo.localId), [
      'b',
      'a',
    ]);
  });

  test('clearing one photo leaves the others', () async {
    await record('a');
    await record('b');

    await repository.clear('a');

    expect((await repository.list()).single.photo.localId, 'b');
  });

  test('clearAll empties the list', () async {
    await record('a');
    await record('b');

    await repository.clearAll();

    expect(await repository.list(), isEmpty);
  });

  test('failures are scoped to the account they were recorded for', () async {
    await record('a');

    // Another account on the same device sees a clean slate — the same
    // photo may well upload fine there.
    await sessions.save(
      AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        email: 'someone@else.example',
        scopes: const ['media:view'],
      ),
    );
    expect(await repository.list(), isEmpty);

    await sessions.save(testAuthSession);
    expect(await repository.list(), hasLength(1));
  });

  test('signed out, nothing is stored and nothing is listed', () async {
    await sessions.clear();

    await record('a');

    expect(await repository.list(), isEmpty);
  });

  test('a change is announced for writes that changed something', () async {
    final seen = <void>[];
    final subscription = repository.changes.listen(seen.add);
    addTearDown(subscription.cancel);

    await record('a');
    await repository.clear('a');
    // Clearing a photo that was never failing is the common case after a
    // successful upload; announcing it would rebuild the list for nothing.
    await repository.clear('never-failed');
    await pumpEventQueue();

    expect(seen, hasLength(2));
  });
}
