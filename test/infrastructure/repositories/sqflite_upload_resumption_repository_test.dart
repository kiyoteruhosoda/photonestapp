import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/entities/upload_resumption.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_upload_resumption_repository.dart';
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
  late SqfliteUploadResumptionRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
    repository = SqfliteUploadResumptionRepository(db, sessions, endpoints);
  });

  tearDown(() async {
    await db.close();
  });

  UploadResumption resumption({
    String localId = 'asset-1',
    String fileName = 'IMG_0001.jpg',
    int fileSize = 1024,
    String tempFileId = 'tmp-1',
  }) {
    return UploadResumption(
      localId: localId,
      fileName: fileName,
      fileSize: fileSize,
      uploadSessionId: 'session-1',
      tempFileId: tempFileId,
    );
  }

  test('an unknown photo has no resume point', () async {
    expect(await repository.find('asset-1'), isNull);
  });

  test('a saved record round-trips whole', () async {
    await repository.save(resumption());

    final stored = await repository.find('asset-1');
    expect(stored, isNotNull);
    expect(stored!.fileName, 'IMG_0001.jpg');
    expect(stored.fileSize, 1024);
    expect(stored.uploadSessionId, 'session-1');
    expect(stored.tempFileId, 'tmp-1');
  });

  test('saving the same photo again replaces the earlier record', () async {
    await repository.save(resumption(tempFileId: 'tmp-1'));
    await repository.save(resumption(tempFileId: 'tmp-2'));

    expect((await repository.find('asset-1'))?.tempFileId, 'tmp-2');
    expect(await db.query(AppDatabase.uploadResumptionsTable), hasLength(1));
  });

  test('clearing forgets only that photo', () async {
    await repository.save(resumption());
    await repository.save(resumption(localId: 'asset-2'));

    await repository.clear('asset-1', tempFileId: 'tmp-1');

    expect(await repository.find('asset-1'), isNull);
    expect(await repository.find('asset-2'), isNotNull);
  });

  test('clearing a photo that has no record is not an error', () async {
    await repository.clear('asset-1', tempFileId: 'tmp-1');

    expect(await repository.find('asset-1'), isNull);
  });

  test('clearing leaves a record that belongs to another upload', () async {
    // A manual upload and an automatic pass overlapped: the row now names
    // the other upload's temp file, and finishing first must not throw away
    // everything that one has sent.
    await repository.save(resumption(tempFileId: 'tmp-2'));

    await repository.clear('asset-1', tempFileId: 'tmp-1');

    expect((await repository.find('asset-1'))?.tempFileId, 'tmp-2');
  });

  test('records are scoped to the account they were sent to', () async {
    await repository.save(resumption());

    // Same device, another account: a temp file belongs to one server, so
    // offering this resume point there would address nothing.
    await sessions.save(
      AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        email: 'someone@else.example',
        scopes: const ['media:upload'],
      ),
    );
    expect(await repository.find('asset-1'), isNull);

    await sessions.save(testAuthSession);
    expect(await repository.find('asset-1'), isNotNull);
  });

  test('signed out there is nothing to read and nothing is written', () async {
    await sessions.clear();

    await repository.save(resumption());

    expect(await repository.find('asset-1'), isNull);
    expect(await db.query(AppDatabase.uploadResumptionsTable), isEmpty);
  });
}
