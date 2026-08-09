import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/thumbnail_url_batch.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/log_level.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  group('GetMediaThumbnailUseCase', () {
    late FakeMediaThumbnailRepository repository;
    late FakeMediaThumbnailUrlRepository urls;
    late FakeMediaThumbnailCacheRepository cache;
    late RecordingAppLogger logger;

    setUp(() {
      repository = FakeMediaThumbnailRepository();
      urls = FakeMediaThumbnailUrlRepository();
      cache = FakeMediaThumbnailCacheRepository();
      logger = RecordingAppLogger();
    });

    GetMediaThumbnailUseCase usecase() => GetMediaThumbnailUseCase(
      repository,
      cache,
      logger,
      ThumbnailUrlBatch(urls, logger),
    );

    test('a miss reads through a signed URL and feeds the cache', () async {
      final bytes = await usecase().execute(MediaId(4), size: 1024);

      expect(bytes, isNotEmpty);
      // Records compare their List field by identity, so the parts are
      // asserted separately.
      expect(urls.issued, hasLength(1));
      expect(urls.issued.single.$1, [MediaId(4)]);
      expect(urls.issued.single.$2, 1024);
      expect(repository.fetchedFrom, hasLength(1));
      // The app server is not asked for the bytes.
      expect(repository.fetched, isEmpty);
      expect(cache.entries[(4, 1024)], bytes);
    });

    test('serves a cache hit without touching the network', () async {
      final cached = Uint8List.fromList([1, 2, 3]);
      cache.entries[(4, 512)] = cached;

      final bytes = await usecase().execute(MediaId(4));

      expect(bytes, cached);
      expect(repository.fetched, isEmpty);
      expect(repository.fetchedFrom, isEmpty);
      // No URL is issued for something already on the device.
      expect(urls.issued, isEmpty);
    });

    test('defaults to the grid size', () async {
      await usecase().execute(MediaId(4));
      expect(urls.issued.single.$2, 512);
    });

    test(
      'media the server will not issue for falls back to the app server',
      () async {
        urls.unissuable.add(4);

        final bytes = await usecase().execute(MediaId(4));

        expect(bytes, isNotEmpty);
        expect(repository.fetched, [(MediaId(4), 512)]);
        expect(repository.fetchedFrom, isEmpty);
      },
    );

    test(
      'a failed batch falls back to the app server for every tile',
      () async {
        urls.failure = const InfrastructureError('issuing is down');

        final bytes = await usecase().execute(MediaId(4));

        expect(bytes, isNotEmpty);
        expect(repository.fetched, hasLength(1));
        expect(logger.messagesAt(LogLevel.warning), hasLength(1));
      },
    );

    test('an expired or unreachable signed URL falls back', () async {
      // The URL is issued, but the edge refuses it — the app server can
      // still answer, so the tile must not stay blank.
      repository.signedFailure = const InfrastructureError('403 from edge');

      final bytes = await usecase().execute(MediaId(4));

      expect(bytes, isNotEmpty);
      expect(repository.fetched, [(MediaId(4), 512)]);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });

    test('a broken cache degrades to fetching instead of failing', () async {
      cache.failure = const InfrastructureError('cache gone');

      final bytes = await usecase().execute(MediaId(4));

      expect(bytes, isNotEmpty);
      expect(repository.fetchedFrom, hasLength(1));
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
