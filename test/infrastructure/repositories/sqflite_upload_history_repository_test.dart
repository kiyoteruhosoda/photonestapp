import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_upload_history_repository.dart';
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
  late SqfliteUploadHistoryRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
    repository = SqfliteUploadHistoryRepository(db, sessions, endpoints);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts empty', () async {
    expect(await repository.uploadedLocalIds(), isEmpty);
  });

  test('remembers uploaded photos by their local id', () async {
    await repository.markUploaded(
      testLocalPhoto(localId: 'a'),
      testPhotoTakenAt,
    );
    await repository.markUploaded(
      testLocalPhoto(localId: 'b', fileName: 'IMG_2.jpg'),
      testPhotoTakenAt,
    );

    expect(await repository.uploadedLocalIds(), {'a', 'b'});
  });

  test('marking the same photo twice keeps one row', () async {
    final photo = testLocalPhoto(localId: 'a');
    await repository.markUploaded(photo, testPhotoTakenAt);
    await repository.markUploaded(photo, testPhotoTakenAt);

    expect(await repository.uploadedLocalIds(), {'a'});
    expect(await db.query(AppDatabase.uploadedPhotosTable), hasLength(1));
  });

  test('stores the upload instant in UTC ISO-8601', () async {
    await repository.markUploaded(
      testLocalPhoto(localId: 'a'),
      DateTime.utc(2026, 8, 3, 12, 30),
    );
    final row = (await db.query(AppDatabase.uploadedPhotosTable)).single;
    expect(row['uploaded_at'], '2026-08-03T12:30:00.000Z');
  });

  test('the history is scoped to the signed-in account', () async {
    await repository.markUploaded(
      testLocalPhoto(localId: 'a'),
      testPhotoTakenAt,
    );

    // Another account on the same server starts with a clean history.
    final otherAccount = SqfliteUploadHistoryRepository(
      db,
      FakeSessionRepository(
        AuthSession(
          accessToken: 'x',
          refreshToken: 'y',
          email: 'other@example.com',
        ),
      ),
      endpoints,
    );
    expect(await otherAccount.uploadedLocalIds(), isEmpty);

    // The same account on another server does too.
    final otherServer = SqfliteUploadHistoryRepository(
      db,
      sessions,
      FakeApiEndpointRepository(Uri.parse('https://elsewhere.example.com')),
    );
    expect(await otherServer.uploadedLocalIds(), isEmpty);

    // The original account still sees its row.
    expect(await repository.uploadedLocalIds(), {'a'});
  });

  test(
    'signed out: nothing counts as uploaded, and marking is refused', //
    () async {
      await repository.markUploaded(
        testLocalPhoto(localId: 'a'),
        testPhotoTakenAt,
      );
      await sessions.clear();

      expect(await repository.uploadedLocalIds(), isEmpty);
      expect(
        repository.markUploaded(testLocalPhoto(localId: 'b'), testPhotoTakenAt),
        throwsA(isA<AuthenticationError>()),
      );
    },
  );

  test('translates database failures into InfrastructureError', () async {
    await db.close();
    expect(repository.uploadedLocalIds(), throwsA(isA<InfrastructureError>()));
    expect(
      repository.markUploaded(testLocalPhoto(), testPhotoTakenAt),
      throwsA(isA<InfrastructureError>()),
    );
  });
}
