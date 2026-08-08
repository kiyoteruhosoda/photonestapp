import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_media_thumbnail_cache_repository.dart';
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

  final fetchedAt = DateTime.utc(2026, 8, 1);

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  SqfliteMediaThumbnailCacheRepository repository({
    int maxTotalBytes =
        SqfliteMediaThumbnailCacheRepository.defaultMaxTotalBytes,
    DateTime Function()? clock,
  }) {
    return SqfliteMediaThumbnailCacheRepository(
      db,
      sessions,
      endpoints,
      maxTotalBytes: maxTotalBytes,
      clock: clock,
    );
  }

  Uint8List bytes(int filler, [int length = 4]) =>
      Uint8List.fromList(List.filled(length, filler));

  test('misses before anything was stored', () async {
    expect(await repository().find(MediaId(1), size: 256), isNull);
  });

  test('returns what was stored, keyed by media and size', () async {
    final subject = repository();
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(7),
      fetchedAt: fetchedAt,
    );

    expect(await subject.find(MediaId(1), size: 256), bytes(7));
    expect(await subject.find(MediaId(1), size: 512), isNull);
    expect(await subject.find(MediaId(2), size: 256), isNull);
  });

  test('replaces an entry saved again at the same key', () async {
    final subject = repository();
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(1),
      fetchedAt: fetchedAt,
    );
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(2),
      fetchedAt: fetchedAt,
    );

    expect(await subject.find(MediaId(1), size: 256), bytes(2));
  });

  test('is scoped to the signed-in server and account', () async {
    final subject = repository();
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(1),
      fetchedAt: fetchedAt,
    );

    endpoints = FakeApiEndpointRepository(Uri.parse('https://other.example'));
    expect(await repository().find(MediaId(1), size: 256), isNull);
  });

  test('misses instead of failing while signed out', () async {
    sessions = FakeSessionRepository();
    final subject = repository();

    expect(await subject.find(MediaId(1), size: 256), isNull);
    // And storing while signed out silently does nothing.
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(1),
      fetchedAt: fetchedAt,
    );
  });

  test('evicts the least recently used entries beyond the budget', () async {
    var tick = 0;
    final subject = repository(
      maxTotalBytes: 12,
      clock: () => fetchedAt.add(Duration(minutes: ++tick)),
    );
    for (var id = 1; id <= 3; id++) {
      await subject.save(
        MediaId(id),
        size: 256,
        bytes: bytes(id),
        fetchedAt: fetchedAt.add(Duration(seconds: id)),
      );
    }
    // Touch the oldest entry so it is no longer the eviction candidate.
    await subject.find(MediaId(1), size: 256);

    // A fourth 4-byte entry pushes the total to 16; the least recently used
    // entry — media 2, untouched — is the one that has to go.
    await subject.save(
      MediaId(4),
      size: 256,
      bytes: bytes(4),
      fetchedAt: fetchedAt.add(const Duration(seconds: 10)),
    );

    expect(await subject.find(MediaId(2), size: 256), isNull);
    expect(await subject.find(MediaId(1), size: 256), bytes(1));
    expect(await subject.find(MediaId(3), size: 256), bytes(3));
    expect(await subject.find(MediaId(4), size: 256), bytes(4));
  });

  test('a large save evicts as many entries as it must', () async {
    final subject = repository(maxTotalBytes: 10);
    await subject.save(
      MediaId(1),
      size: 256,
      bytes: bytes(1),
      fetchedAt: fetchedAt,
    );
    await subject.save(
      MediaId(2),
      size: 256,
      bytes: bytes(2),
      fetchedAt: fetchedAt.add(const Duration(seconds: 1)),
    );

    // 9 bytes on its own: everything older has to go.
    await subject.save(
      MediaId(3),
      size: 256,
      bytes: bytes(3, 9),
      fetchedAt: fetchedAt.add(const Duration(seconds: 2)),
    );

    expect(await subject.find(MediaId(1), size: 256), isNull);
    expect(await subject.find(MediaId(2), size: 256), isNull);
    expect(await subject.find(MediaId(3), size: 256), bytes(3, 9));
  });
}
