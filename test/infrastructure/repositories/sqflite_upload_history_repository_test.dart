import 'package:flutter_test/flutter_test.dart';
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
  late SqfliteUploadHistoryRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SqfliteUploadHistoryRepository(db);
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

  test('translates database failures into InfrastructureError', () async {
    await db.close();
    expect(repository.uploadedLocalIds(), throwsA(isA<InfrastructureError>()));
    expect(
      repository.markUploaded(testLocalPhoto(), testPhotoTakenAt),
      throwsA(isA<InfrastructureError>()),
    );
  });
}
