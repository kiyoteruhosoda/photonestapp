import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/media/get_media_playback_usecase.dart';
import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';

void main() {
  group('GetMediaPlaybackUseCase', () {
    test('hands back the repository source for the media', () async {
      final repository = FakeMediaPlaybackRepository();
      final source = SignedMediaUrl(
        url: Uri.parse('https://photos.example.com/api/dl/tok'),
        expiresAt: DateTime.utc(2026, 8, 8, 12),
      );
      repository.sources[7] = source;

      final result = await GetMediaPlaybackUseCase(
        repository,
      ).execute(MediaId(7));

      expect(result, source);
      expect(repository.requested, [MediaId(7)]);
    });

    test('propagates repository failures', () {
      final repository = FakeMediaPlaybackRepository()
        ..failure = const InfrastructureError('processing', code: 'not_ready');
      expect(
        GetMediaPlaybackUseCase(repository).execute(MediaId(7)),
        throwsA(
          isA<InfrastructureError>().having(
            (error) => error.code,
            'code',
            'not_ready',
          ),
        ),
      );
    });
  });
}
