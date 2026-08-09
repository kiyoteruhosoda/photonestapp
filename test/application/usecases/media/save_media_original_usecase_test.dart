import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeMediaOriginalRepository originals;
  late FakePhotoLibraryGateway library;
  late RecordingAppLogger logger;

  setUp(() {
    originals = FakeMediaOriginalRepository();
    library = FakePhotoLibraryGateway();
    logger = RecordingAppLogger();
  });

  SaveMediaOriginalUseCase usecase() =>
      SaveMediaOriginalUseCase(originals, library, logger);

  test('downloads the original and files it under its own name', () async {
    originals.bytes = Uint8List.fromList([9, 9]);

    final failure = await usecase().execute(
      MediaId(4),
      fileName: 'IMG_4.jpg',
      isVideo: false,
    );

    expect(failure, isNull);
    expect(originals.downloaded.single.value, 4);
    expect(library.savedToLibrary.single, (
      'IMG_4.jpg',
      originals.bytes,
      false,
    ));
  });

  test('a video is filed as a video, not as an image', () async {
    await usecase().execute(MediaId(4), fileName: 'clip.mp4', isVideo: true);

    expect(library.savedToLibrary.single.$3, isTrue);
  });

  test('a denied grant stops before the download', () async {
    library.accessGranted = false;

    final failure = await usecase().execute(
      MediaId(4),
      fileName: 'IMG_4.jpg',
      isVideo: false,
    );

    expect(failure, SaveMediaFailure.noLibraryAccess);
    expect(originals.downloaded, isEmpty);
  });

  test('an unreachable server becomes a reason, not an exception', () async {
    originals.failure = const NetworkUnreachableError('offline');

    final failure = await usecase().execute(
      MediaId(4),
      fileName: 'IMG_4.jpg',
      isVideo: false,
    );

    expect(failure, SaveMediaFailure.downloadFailed);
    expect(library.savedToLibrary, isEmpty);
  });

  test('a platform that refuses to write is reported', () async {
    library.saveGranted = false;

    final failure = await usecase().execute(
      MediaId(4),
      fileName: 'IMG_4.jpg',
      isVideo: false,
    );

    expect(failure, SaveMediaFailure.writeFailed);
  });
}
