import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  group('GetMediaThumbnailUseCase', () {
    late FakeMediaThumbnailRepository repository;
    late FakeMediaThumbnailCacheRepository cache;
    late RecordingAppLogger logger;

    setUp(() {
      repository = FakeMediaThumbnailRepository();
      cache = FakeMediaThumbnailCacheRepository();
      logger = RecordingAppLogger();
    });

    GetMediaThumbnailUseCase usecase() =>
        GetMediaThumbnailUseCase(repository, cache, logger);

    test('fetches from the repository and feeds the cache on a miss', () async {
      final bytes = await usecase().execute(MediaId(4), size: 1024);

      expect(bytes, isNotEmpty);
      expect(repository.fetched, [(MediaId(4), 1024)]);
      expect(cache.entries[(4, 1024)], bytes);
    });

    test('serves a cache hit without touching the network', () async {
      final cached = Uint8List.fromList([1, 2, 3]);
      cache.entries[(4, 512)] = cached;

      final bytes = await usecase().execute(MediaId(4));

      expect(bytes, cached);
      expect(repository.fetched, isEmpty);
    });

    test('defaults to the grid size', () async {
      await usecase().execute(MediaId(4));
      expect(repository.fetched.single.$2, 512);
    });

    test('a broken cache degrades to fetching instead of failing', () async {
      cache.failure = const InfrastructureError('cache gone');

      final bytes = await usecase().execute(MediaId(4));

      expect(bytes, isNotEmpty);
      expect(repository.fetched, hasLength(1));
      // Both the read and the write failure were logged, not swallowed.
      expect(logger.messagesAt(LogLevel.warning), hasLength(2));
    });

    test('propagates repository failures', () {
      repository.failure = const InfrastructureError('missing');
      expect(
        usecase().execute(MediaId(1)),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });
}
