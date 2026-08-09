import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/media/thumbnail_url_batch.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_thumbnail_url_repository.dart';
import 'package:photonest/domain/value_objects/log_level.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  group('ThumbnailUrlBatch', () {
    late FakeMediaThumbnailUrlRepository urls;
    late RecordingAppLogger logger;

    setUp(() {
      urls = FakeMediaThumbnailUrlRepository();
      logger = RecordingAppLogger();
    });

    ThumbnailUrlBatch batch({int maxBatchSize = maxThumbnailUrlBatchSize}) =>
        ThumbnailUrlBatch(urls, logger, maxBatchSize: maxBatchSize);

    test('everything asked for in one go becomes one request', () async {
      final subject = batch();

      // What a grid does: every visible tile asks during the same frame.
      final results = await Future.wait([
        for (var id = 1; id <= 30; id++) subject.urlFor(MediaId(id), size: 256),
      ]);

      expect(urls.issued, hasLength(1));
      expect(urls.issued.single.$1, hasLength(30));
      expect(results.every((url) => url != null), isTrue);
    });

    test('the same thumbnail asked for twice is issued once', () async {
      final subject = batch();

      final results = await Future.wait([
        subject.urlFor(MediaId(1), size: 256),
        subject.urlFor(MediaId(1), size: 256),
      ]);

      expect(urls.issued.single.$1, [MediaId(1)]);
      expect(results.first, results.last);
    });

    test('different sizes go in separate requests', () async {
      final subject = batch();

      await Future.wait([
        subject.urlFor(MediaId(1), size: 256),
        subject.urlFor(MediaId(2), size: 1024),
      ]);

      expect(urls.issued, hasLength(2));
      expect(urls.issued.map((batch) => batch.$2).toSet(), {256, 1024});
    });

    test('a batch larger than the server allows is split', () async {
      final subject = batch(maxBatchSize: 10);

      await Future.wait([
        for (var id = 1; id <= 25; id++) subject.urlFor(MediaId(id), size: 256),
      ]);

      expect(urls.issued.map((batch) => batch.$1.length), [10, 10, 5]);
    });

    test('a later frame is a new request, not a wait on the first', () async {
      final subject = batch();
      await subject.urlFor(MediaId(1), size: 256);

      await subject.urlFor(MediaId(2), size: 256);

      expect(urls.issued, hasLength(2));
    });

    test('media the server will not issue for answers null', () async {
      urls.unissuable.add(2);
      final subject = batch();

      final results = await Future.wait([
        subject.urlFor(MediaId(1), size: 256),
        subject.urlFor(MediaId(2), size: 256),
      ]);

      expect(results.first, isNotNull);
      expect(results.last, isNull);
    });

    test('a failed request answers null rather than throwing', () async {
      // Every waiter falls back to the app server, so the grid still fills.
      urls.failure = const InfrastructureError('issuing is down');
      final subject = batch();

      final results = await Future.wait([
        subject.urlFor(MediaId(1), size: 256),
        subject.urlFor(MediaId(2), size: 256),
      ]);

      expect(results, [null, null]);
      expect(logger.messagesAt(LogLevel.warning), hasLength(1));
    });
  });
}
