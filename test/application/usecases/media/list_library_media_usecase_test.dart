import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeMediaLibraryRepository library;
  late RecordingAppLogger logger;

  setUp(() {
    library = FakeMediaLibraryRepository();
    logger = RecordingAppLogger();
  });

  ListLibraryMediaUseCase usecase() => ListLibraryMediaUseCase(library, logger);

  test('passes the requested window through to the repository', () async {
    library.media = [for (var i = 1; i <= 5; i++) testMediaItem(id: i)];

    final page = await usecase().execute(page: 2, pageSize: 2);

    expect(library.requestedPages, [(2, 2)]);
    expect(page.items.map((item) => item.id.value), [3, 4]);
    expect(page.hasNext, isTrue);
  });

  test('the last page reports no more', () async {
    library.media = [for (var i = 1; i <= 4; i++) testMediaItem(id: i)];

    final page = await usecase().execute(page: 2, pageSize: 2);

    expect(page.items, hasLength(2));
    expect(page.hasNext, isFalse);
  });

  test('an empty library is an answer, not a failure', () async {
    final page = await usecase().execute();

    expect(page.items, isEmpty);
    expect(page.hasNext, isFalse);
  });

  test('a repository failure reaches the caller', () {
    library.failure = const NetworkUnreachableError('offline');
    expect(usecase().execute, throwsA(isA<NetworkUnreachableError>()));
  });
}
