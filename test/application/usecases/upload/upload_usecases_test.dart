import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakePhotoLibraryGateway library;
  late FakeUploadHistoryRepository history;
  late FakePhotoUploadRepository uploads;
  late FakeAutoUploadSettingsRepository settings;
  late FakeSessionRepository sessions;
  late RecordingAppLogger logger;

  setUp(() {
    library = FakePhotoLibraryGateway();
    history = FakeUploadHistoryRepository();
    uploads = FakePhotoUploadRepository();
    settings = FakeAutoUploadSettingsRepository();
    sessions = FakeSessionRepository(testAuthSession);
    logger = RecordingAppLogger();
  });

  UploadPhotosUseCase uploadUseCase() =>
      UploadPhotosUseCase(library, uploads, history, logger);

  SyncNewPhotosUseCase syncUseCase() => SyncNewPhotosUseCase(
    settings,
    sessions,
    library,
    history,
    uploadUseCase(),
    logger,
  );

  group('ListUploadCandidatesUseCase', () {
    test('reports denied access without touching the library', () async {
      library.accessGranted = false;
      final result = await ListUploadCandidatesUseCase(
        library,
        history,
      ).execute();
      expect(result.accessGranted, isFalse);
      expect(result.photos, isEmpty);
      expect(library.queriedSince, isEmpty);
    });

    test('marks photos the history already knows as uploaded', () async {
      library.photos = [
        testLocalPhoto(localId: 'a'),
        testLocalPhoto(localId: 'b'),
      ];
      history = FakeUploadHistoryRepository({'b'});

      final result = await ListUploadCandidatesUseCase(
        library,
        history,
      ).execute();

      expect(result.accessGranted, isTrue);
      expect(result.photos, hasLength(2));
      expect(result.photos[0].alreadyUploaded, isFalse);
      expect(result.photos[1].alreadyUploaded, isTrue);
    });
  });

  group('UploadPhotosUseCase', () {
    test('uploads each photo and records it in the history', () async {
      final photoA = testLocalPhoto(localId: 'a');
      final photoB = testLocalPhoto(localId: 'b', fileName: 'IMG_2.jpg');
      library.bytesById['a'] = Uint8List.fromList([1]);
      library.bytesById['b'] = Uint8List.fromList([2]);

      final result = await uploadUseCase().execute([
        photoA,
        photoB,
      ], uploadedAt: testPhotoTakenAt);

      expect(result.uploaded, [photoA, photoB]);
      expect(result.failed, isEmpty);
      expect(uploads.uploaded.map((entry) => entry.$1), [photoA, photoB]);
      expect(history.marked, [photoA, photoB]);
    });

    test('a vanished asset becomes a failure, not an exception', () async {
      final photo = testLocalPhoto(localId: 'gone');

      final result = await uploadUseCase().execute([photo]);

      expect(result.uploaded, isEmpty);
      expect(result.failed, hasLength(1));
      expect(result.failed.single.photo, photo);
      expect(history.marked, isEmpty);
    });

    test(
      'one rejected photo does not poison the rest of the batch', //
      () async {
        final good = testLocalPhoto(localId: 'good');
        final bad = testLocalPhoto(localId: 'bad');
        library.bytesById['good'] = Uint8List.fromList([1]);
        library.bytesById['bad'] = Uint8List.fromList([2]);
        uploads.failure = const InfrastructureError('too large');
        uploads.failFor = {'bad'};

        final result = await uploadUseCase().execute([bad, good]);

        expect(result.uploaded, [good]);
        expect(result.failed.single.photo, bad);
        expect(result.hasFailures, isTrue);
        expect(history.marked, [good]);
      },
    );

    test('classifies each failure so the UI can translate it', () async {
      final vanished = testLocalPhoto(localId: 'gone');
      final unsupported = testLocalPhoto(localId: 'raw');
      final expired = testLocalPhoto(localId: 'expired');
      final refused = testLocalPhoto(localId: 'refused');
      library.bytesById['raw'] = Uint8List.fromList([1]);
      library.bytesById['expired'] = Uint8List.fromList([2]);
      library.bytesById['refused'] = Uint8List.fromList([3]);

      uploads.failure = const InfrastructureError(
        'Unsupported photo type ".cr2".',
        code: 'unsupported_format',
      );
      uploads.failFor = {'raw'};
      var result = await uploadUseCase().execute([vanished, unsupported]);
      expect(
        result.failed[0].reason,
        PhotoUploadFailureReason.missingFromLibrary,
      );
      expect(
        result.failed[1].reason,
        PhotoUploadFailureReason.unsupportedFormat,
      );

      uploads.failure = const AuthenticationError('The session has expired.');
      uploads.failFor = {'expired'};
      result = await uploadUseCase().execute([expired]);
      expect(
        result.failed.single.reason,
        PhotoUploadFailureReason.sessionExpired,
      );

      uploads.failure = const InfrastructureError('HTTP 500');
      uploads.failFor = {'refused'};
      result = await uploadUseCase().execute([refused]);
      expect(result.failed.single.reason, PhotoUploadFailureReason.rejected);
    });

    test('reports progress after each settled photo', () async {
      final photos = [
        testLocalPhoto(localId: 'a'),
        testLocalPhoto(localId: 'b'),
        testLocalPhoto(localId: 'c'),
      ];
      library.bytesById['a'] = Uint8List.fromList([1]);
      library.bytesById['c'] = Uint8List.fromList([3]);
      // 'b' has no bytes — it fails, and still counts as settled.

      final ticks = <(int, int)>[];
      await uploadUseCase().execute(
        photos,
        onProgress: (completed, total) => ticks.add((completed, total)),
      );

      expect(ticks, [(1, 3), (2, 3), (3, 3)]);
    });

    test(
      'cancellation stops before the next photo, keeping what was sent', //
      () async {
        final photos = [
          testLocalPhoto(localId: 'a'),
          testLocalPhoto(localId: 'b'),
          testLocalPhoto(localId: 'c'),
        ];
        for (final photo in photos) {
          library.bytesById[photo.localId] = Uint8List.fromList([1]);
        }

        final cancellation = UploadCancellation();
        final result = await uploadUseCase().execute(
          photos,
          onProgress: (completed, _) {
            if (completed == 1) cancellation.cancel();
          },
          cancellation: cancellation,
        );

        expect(result.cancelled, isTrue);
        expect(result.uploaded.map((photo) => photo.localId), ['a']);
        expect(result.failed, isEmpty);
        // The photo already sent stays recorded; the rest were never attempted.
        expect(history.marked, hasLength(1));
        expect(uploads.uploaded, hasLength(1));
      },
    );

    test('an unused cancellation changes nothing', () async {
      final photo = testLocalPhoto(localId: 'a');
      library.bytesById['a'] = Uint8List.fromList([1]);

      final result = await uploadUseCase().execute([
        photo,
      ], cancellation: UploadCancellation());

      expect(result.cancelled, isFalse);
      expect(result.uploaded, [photo]);
    });
  });

  group('SyncNewPhotosUseCase', () {
    test('skips when auto-upload is off', () async {
      settings.enabled = false;
      final report = await syncUseCase().execute();
      expect(report.skipped, SyncSkipReason.disabled);
      expect(report.uploadedCount, 0);
    });

    test('skips when nobody is signed in', () async {
      settings.enabled = true;
      sessions = FakeSessionRepository();
      final report = await syncUseCase().execute();
      expect(report.skipped, SyncSkipReason.notSignedIn);
    });

    test('skips when the library access is denied', () async {
      settings.enabled = true;
      library.accessGranted = false;
      final report = await syncUseCase().execute();
      expect(report.skipped, SyncSkipReason.noLibraryAccess);
    });

    test('uploads only photos taken after the enable stamp and not yet '
        'uploaded', () async {
      settings
        ..enabled = true
        ..since = DateTime.utc(2026, 8, 1);
      final old = testLocalPhoto(
        localId: 'old',
        takenAt: DateTime.utc(2026, 7, 1),
      );
      final done = testLocalPhoto(
        localId: 'done',
        takenAt: DateTime.utc(2026, 8, 2),
      );
      final fresh = testLocalPhoto(
        localId: 'fresh',
        takenAt: DateTime.utc(2026, 8, 3),
      );
      library.photos = [old, done, fresh];
      library.bytesById['fresh'] = Uint8List.fromList([1]);
      history = FakeUploadHistoryRepository({'done'});

      final report = await syncUseCase().execute();

      expect(report.skipped, isNull);
      expect(report.uploadedCount, 1);
      expect(uploads.uploaded.single.$1, fresh);
      expect(library.queriedSince, [DateTime.utc(2026, 8, 1)]);
    });

    test('pages past already-uploaded photos so older pending ones are '
        'found', () async {
      // Newest-first library: page one is entirely uploaded already. A
      // single-page sync would filter it all out and stop — the older
      // pending photos would stay unsynchronised forever.
      settings
        ..enabled = true
        ..since = DateTime.utc(2026, 8, 1);
      library.photos = [
        for (var i = 0; i < 5; i++)
          testLocalPhoto(
            localId: 'photo-$i',
            takenAt: DateTime.utc(2026, 8, 5, 10 - i),
          ),
      ];
      library.bytesById['photo-3'] = Uint8List.fromList([1]);
      library.bytesById['photo-4'] = Uint8List.fromList([2]);
      history = FakeUploadHistoryRepository({'photo-0', 'photo-1', 'photo-2'});

      final paged = SyncNewPhotosUseCase(
        settings,
        sessions,
        library,
        history,
        uploadUseCase(),
        logger,
        pageSize: 3,
      );
      final report = await paged.execute();

      expect(report.uploadedCount, 2);
      expect(
        uploads.uploaded.map((entry) => entry.$1.localId),
        containsAll(['photo-3', 'photo-4']),
      );
    });

    test('an empty library yields an empty successful report', () async {
      settings
        ..enabled = true
        ..since = DateTime.utc(2026, 8, 1);
      final report = await syncUseCase().execute();
      expect(report.skipped, isNull);
      expect(report.uploadedCount, 0);
      expect(report.result, isNotNull);
    });
  });

  group('GetAutoUploadEnabledUseCase', () {
    test('mirrors the stored flag', () {
      expect(GetAutoUploadEnabledUseCase(settings).execute(), isFalse);
      settings.enabled = true;
      expect(GetAutoUploadEnabledUseCase(settings).execute(), isTrue);
    });
  });

  group('SetAutoUploadEnabledUseCase', () {
    SetAutoUploadEnabledUseCase usecase() =>
        SetAutoUploadEnabledUseCase(settings, library, logger);

    test('enables when the library access is granted', () async {
      expect(await usecase().execute(true), isTrue);
      expect(settings.enabled, isTrue);
    });

    test('refuses to enable when the user denies photo access', () async {
      library.accessGranted = false;
      expect(await usecase().execute(true), isFalse);
      expect(settings.enabled, isFalse);
    });

    test('disabling never asks for access', () async {
      settings.enabled = true;
      expect(await usecase().execute(false), isFalse);
      expect(settings.enabled, isFalse);
      expect(library.accessRequests, 0);
    });
  });

  group('GetLocalThumbnailUseCase', () {
    test('reads the preview from the gateway', () async {
      library.thumbnailsById['a'] = Uint8List.fromList([9]);
      final bytes = await GetLocalThumbnailUseCase(library).execute('a');
      expect(bytes, Uint8List.fromList([9]));
    });

    test('returns null for a vanished asset', () async {
      expect(await GetLocalThumbnailUseCase(library).execute('gone'), isNull);
    });
  });
}
