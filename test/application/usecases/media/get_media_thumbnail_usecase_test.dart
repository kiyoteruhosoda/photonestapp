import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';

void main() {
  group('GetMediaThumbnailUseCase', () {
    test('fetches from the repository at the requested size', () async {
      final repository = FakeMediaThumbnailRepository();
      final usecase = GetMediaThumbnailUseCase(repository);

      final bytes = await usecase.execute(MediaId(4), size: 1024);

      expect(bytes, isNotEmpty);
      expect(repository.fetched, [(MediaId(4), 1024)]);
    });

    test('defaults to the grid size', () async {
      final repository = FakeMediaThumbnailRepository();
      await GetMediaThumbnailUseCase(repository).execute(MediaId(4));
      expect(repository.fetched.single.$2, 512);
    });

    test('propagates repository failures', () {
      final repository = FakeMediaThumbnailRepository()
        ..failure = const InfrastructureError('missing');
      expect(
        GetMediaThumbnailUseCase(repository).execute(MediaId(1)),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });
}
