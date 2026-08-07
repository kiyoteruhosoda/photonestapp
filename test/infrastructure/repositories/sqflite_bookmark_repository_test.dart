import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_bookmark_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteBookmarkRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SqfliteBookmarkRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  BookmarkDraft draft({
    String title = 'Flutter',
    String url = 'https://docs.flutter.dev/get-started?tab=android',
  }) => BookmarkDraft(title: title, url: Uri.parse(url));

  test('add returns the stored bookmark with an assigned id', () async {
    final stored = await repository.add(draft());

    expect(stored.id.value, greaterThan(0));
    expect(stored.title, 'Flutter');
    expect(stored.url.toString(), contains('tab=android'));
    expect(stored.createdAt.isUtc, isTrue);
  });

  test('a stored bookmark survives a round trip unchanged', () async {
    final stored = await repository.add(draft());
    final loaded = await repository.findById(stored.id);

    expect(loaded, isNotNull);
    expect(loaded!.title, stored.title);
    expect(loaded.url, stored.url);
    // Written as ISO-8601 text; the UTC flag has to survive parsing back,
    // or the UI would shift the timestamp by the device's offset.
    expect(loaded.createdAt.isUtc, isTrue);
    expect(
      loaded.createdAt.toIso8601String(),
      stored.createdAt.toIso8601String(),
    );
  });

  test('findById returns null for an id that is not stored', () async {
    expect(await repository.findById(BookmarkId(404)), isNull);
  });

  test('findAll returns the newest bookmark first', () async {
    final first = await repository.add(draft(title: 'first'));
    final second = await repository.add(draft(title: 'second'));

    final all = await repository.findAll();
    expect(all.map((b) => b.id), equals(<BookmarkId>[second.id, first.id]));
  });

  test('findAll is empty before anything is stored', () async {
    expect(await repository.findAll(), isEmpty);
  });

  test('remove deletes only the named bookmark', () async {
    final kept = await repository.add(draft(title: 'kept'));
    final doomed = await repository.add(draft(title: 'doomed'));

    await repository.remove(doomed.id);

    expect(await repository.findById(doomed.id), isNull);
    expect(await repository.findById(kept.id), isNotNull);
  });

  test('removing an id that is not stored is a no-op', () async {
    await repository.add(draft());
    await repository.remove(BookmarkId(404));
    expect(await repository.findAll(), hasLength(1));
  });

  test('a storage failure surfaces as InfrastructureError', () async {
    await db.close();
    expect(
      repository.findAll(),
      throwsA(
        isA<InfrastructureError>().having(
          (e) => e.message,
          'message',
          contains('bookmark list failed'),
        ),
      ),
    );
  });
}
