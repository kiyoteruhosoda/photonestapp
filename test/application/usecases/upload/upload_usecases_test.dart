import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_unmetered_only_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_unmetered_only_usecase.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/entities/upload_failure.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakePhotoLibraryGateway library;
  late FakeUploadHistoryRepository history;
  late FakeUploadFailureRepository failures;
  late FakePhotoUploadRepository uploads;
  late FakeAutoUploadSettingsRepository settings;
  late FakeSessionRepository sessions;
  late FakeNetworkConnectionGateway network;
  late FakeSyncLeaseRepository syncLease;
  late FakeBackupNotificationRepository notifications;
  late RecordingAppLogger logger;

  setUp(() {
    library = FakePhotoLibraryGateway();
    history = FakeUploadHistoryRepository();
    failures = FakeUploadFailureRepository();
    uploads = FakePhotoUploadRepository();
    settings = FakeAutoUploadSettingsRepository();
    sessions = FakeSessionRepository(testAuthSession);
    network = FakeNetworkConnectionGateway();
    syncLease = FakeSyncLeaseRepository();
    notifications = FakeBackupNotificationRepository();
    logger = RecordingAppLogger();
  });

  UploadPhotosUseCase uploadUseCase() =>
      UploadPhotosUseCase(library, uploads, history, failures, logger);

  SyncNewPhotosUseCase syncUseCase() => SyncNewPhotosUseCase(
    settings,
    sessions,
    network,
    library,
    history,
    syncLease,
    uploadUseCase(),
    RecordBackupResultUseCase(notifications, logger),
    logger,
    leaseHolder: 'foreground',
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

      final offline = testLocalPhoto(localId: 'offline');
      library.bytesById['offline'] = Uint8List.fromList([4]);
      uploads.failure = const NetworkUnreachableError('connection refused');
      uploads.failFor = {'offline'};
      result = await uploadUseCase().execute([offline]);
      expect(result.failed.single.reason, PhotoUploadFailureReason.unreachable);

      // A chunked upload that stopped advancing is a transfer to retry, not
      // a photo the server refused — the next pass resumes it.
      final stalled = testLocalPhoto(localId: 'stalled');
      library.bytesById['stalled'] = Uint8List.fromList([5]);
      uploads.failure = const InfrastructureError(
        'Gave up sending IMG_0001.jpg after 3 attempts',
        code: 'upload_stalled',
      );
      uploads.failFor = {'stalled'};
      result = await uploadUseCase().execute([stalled]);
      expect(result.failed.single.reason, PhotoUploadFailureReason.unreachable);
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
        onProgress: (progress) =>
            ticks.add((progress.completed, progress.total)),
      );

      expect(ticks, [(1, 3), (2, 3), (3, 3)]);
    });

    test('byte progress from the file in flight moves the fraction', () async {
      final photos = [testLocalPhoto(localId: 'a')];
      library.bytesById['a'] = Uint8List.fromList([1]);
      uploads.byteProgress = [(50, 200), (200, 200)];

      final fractions = <double>[];
      await uploadUseCase().execute(
        photos,
        onProgress: (progress) => fractions.add(progress.fraction),
      );

      // A single photo whose bytes are half sent is a half-done batch —
      // without this the bar would sit at 0 until the file completed.
      expect(fractions, [0.25, 1.0, 1.0]);
    });

    test('a failure is recorded so it survives the run', () async {
      // 'b' has no bytes, so it fails.
      await uploadUseCase().execute([testLocalPhoto(localId: 'b')]);

      final recorded = await failures.list();
      expect(recorded.single.photo.localId, 'b');
      expect(recorded.single.reason, UploadFailureReason.missingFromLibrary);
      expect(recorded.single.attempts, 1);
      expect(recorded.single.automatic, isFalse);
    });

    test('repeated failures accumulate an attempt count', () async {
      final photo = testLocalPhoto(localId: 'b');
      await uploadUseCase().execute([photo]);
      await uploadUseCase().execute([photo]);

      expect((await failures.list()).single.attempts, 2);
    });

    test('an automatic batch records that nobody was watching', () async {
      // The flag rides on the call, not on the instance: the same use case
      // serves the manual screen and both automatic paths (the foreground
      // coordinator and the WorkManager engine).
      await uploadUseCase().execute([
        testLocalPhoto(localId: 'b'),
      ], automatic: true);

      expect((await failures.list()).single.automatic, isTrue);
    });

    test('a record that cannot be cleared does not lose the upload', () async {
      // The server has already accepted the file; a failing bookkeeping
      // delete must not abort the batch or drop the photo from the result.
      final photo = testLocalPhoto(localId: 'a');
      library.bytesById['a'] = Uint8List.fromList([1]);
      failures.clearFailure = const InfrastructureError('database is locked');

      final result = await uploadUseCase().execute([photo]);

      expect(result.uploaded.map((photo) => photo.localId), ['a']);
      expect(history.marked, hasLength(1));
    });

    test('a photo that finally uploads stops being a failure', () async {
      final photo = testLocalPhoto(localId: 'b');
      await uploadUseCase().execute([photo]);
      expect(await failures.list(), hasLength(1));

      library.bytesById['b'] = Uint8List.fromList([1]);
      await uploadUseCase().execute([photo]);

      expect(await failures.list(), isEmpty);
    });

    test(
      'a failure store that cannot be written does not fail the batch',
      () async {
        failures.recordFailure = const InfrastructureError('disk full');

        final result = await uploadUseCase().execute([
          testLocalPhoto(localId: 'b'),
        ]);

        expect(result.failed, hasLength(1));
        expect(logger.messagesAt(LogLevel.warning), isNotEmpty);
      },
    );

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
          onProgress: (progress) {
            if (progress.completed == 1) cancellation.cancel();
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

    test('failures from a sync pass are recorded as automatic', () async {
      settings
        ..enabled = true
        ..since = DateTime.utc(2026, 8, 1);
      // No bytes for this photo, so the upload fails.
      library.photos = [
        testLocalPhoto(localId: 'broken', takenAt: DateTime.utc(2026, 8, 3)),
      ];

      await syncUseCase().execute();

      // True for the foreground coordinator's passes too, not just the
      // WorkManager engine's — neither has a user watching.
      expect((await failures.list()).single.automatic, isTrue);
    });

    test('skips a metered connection while restricted to unmetered', () async {
      settings.enabled = true;
      network.unmetered = false;
      final report = await syncUseCase().execute();
      expect(report.skipped, SyncSkipReason.meteredConnection);
      // Checked before access, so a skipped pass never prompts for photos.
      expect(library.accessRequests, 0);
    });

    test(
      'stops the batch when the connection turns metered part-way',
      () async {
        settings
          ..enabled = true
          ..since = DateTime.utc(2026, 8, 1);
        for (var i = 0; i < 3; i++) {
          library.photos.add(
            testLocalPhoto(
              localId: 'photo-$i',
              takenAt: DateTime.utc(2026, 8, 3, 10 - i),
            ),
          );
          library.bytesById['photo-$i'] = Uint8List.fromList([i]);
        }
        // Leaves Wi-Fi after the first photo has been sent.
        network.scriptedAnswers = [true, true, false];

        final report = await syncUseCase().execute();

        expect(report.uploadedCount, 1);
        expect(report.result?.cancelled, isTrue);
        // The two that never went out stay unrecorded, so the next pass — on
        // Wi-Fi — picks them up.
        expect(history.marked, hasLength(1));
      },
    );

    test(
      'stops the batch when the restriction is switched on part-way',
      () async {
        settings
          ..enabled = true
          ..unmeteredOnly = false
          ..since = DateTime.utc(2026, 8, 1);
        network.unmetered = false;
        for (var i = 0; i < 3; i++) {
          library.photos.add(
            testLocalPhoto(
              localId: 'photo-$i',
              takenAt: DateTime.utc(2026, 8, 3, 10 - i),
            ),
          );
          library.bytesById['photo-$i'] = Uint8List.fromList([i]);
        }
        // The user flips "only over Wi-Fi" while the batch is running.
        uploads.gate = (_) async => settings.unmeteredOnly = true;

        final report = await syncUseCase().execute();

        expect(report.uploadedCount, 1);
        expect(report.result?.cancelled, isTrue);
      },
    );

    test('uploads over a metered connection once the restriction is '
        'lifted', () async {
      settings
        ..enabled = true
        ..unmeteredOnly = false
        ..since = DateTime.utc(2026, 8, 1);
      network.unmetered = false;
      final fresh = testLocalPhoto(
        localId: 'fresh',
        takenAt: DateTime.utc(2026, 8, 3),
      );
      library.photos = [fresh];
      library.bytesById['fresh'] = Uint8List.fromList([1]);

      final report = await syncUseCase().execute();

      expect(report.skipped, isNull);
      expect(report.uploadedCount, 1);
      // The connection is never even queried when the setting is off.
      expect(network.checks, 0);
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
        network,
        library,
        history,
        syncLease,
        uploadUseCase(),
        RecordBackupResultUseCase(notifications, logger),
        logger,
        leaseHolder: 'foreground',
        pageSize: 3,
      );
      final report = await paged.execute();

      expect(report.uploadedCount, 2);
      // The pass leaves its trace in the notification list.
      expect(notifications.stored.single.uploadedCount, 2);
      expect(notifications.stored.single.failedCount, 0);
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

  group('SyncNewPhotosUseCase — sync lease', () {
    setUp(() {
      settings
        ..enabled = true
        ..since = DateTime.utc(2026, 8, 1);
    });

    test('runs under the lease and releases it afterwards', () async {
      await syncUseCase().execute();

      expect(syncLease.acquiredBy, ['foreground']);
      expect(syncLease.releasedBy, ['foreground']);
      expect(syncLease.heldBy, isNull);
    });

    test('skips the pass while another isolate holds the lease', () async {
      syncLease.heldBy = 'background';
      library.photos = [testLocalPhoto()];
      library.bytesById['asset-1'] = Uint8List.fromList([1]);

      final report = await syncUseCase().execute();

      expect(report.skipped, SyncSkipReason.anotherPassRunning);
      expect(uploads.uploaded, isEmpty);
      // The other isolate's lease is left untouched.
      expect(syncLease.heldBy, 'background');
    });

    test('releases the lease even when the pass throws', () async {
      library.photos = [testLocalPhoto()];
      library.bytesById['asset-1'] = Uint8List.fromList([1]);
      history.failOnRead = true;

      await expectLater(syncUseCase().execute(), throwsA(anything));
      expect(syncLease.heldBy, isNull);
    });
  });

  group('UploadPhotosUseCase — original sources', () {
    test('streams from the platform file when one exists', () async {
      final photo = testLocalPhoto(localId: 'v1', isVideo: true);
      library.photos = [photo];
      library.filePathById['v1'] = '/videos/clip.mp4';
      // Bytes deliberately absent: the path route must not need them.

      final result = await uploadUseCase().execute([photo]);

      expect(result.uploaded, [photo]);
      expect(uploads.uploadedFromPath.single.$2, '/videos/clip.mp4');
      expect(uploads.uploaded, isEmpty);
    });

    test('falls back to in-memory bytes when no file is exposed', () async {
      final photo = testLocalPhoto(localId: 'p1');
      library.photos = [photo];
      library.bytesById['p1'] = Uint8List.fromList([1, 2]);

      final result = await uploadUseCase().execute([photo]);

      expect(result.uploaded, [photo]);
      expect(uploads.uploaded, hasLength(1));
      expect(uploads.uploadedFromPath, isEmpty);
    });

    test('a vanished file counts as missing from the library', () async {
      final photo = testLocalPhoto(localId: 'v1');
      library.filePathById['v1'] = '/videos/deleted.mp4';
      uploads.failure = const InfrastructureError('gone', code: 'missing_file');

      final result = await uploadUseCase().execute([photo]);

      expect(
        result.failed.single.reason,
        PhotoUploadFailureReason.missingFromLibrary,
      );
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
    final backgroundSync = FakeBackgroundSyncScheduler();
    setUp(() {
      backgroundSync
        ..scheduleRequests = 0
        ..cancelRequests = 0
        ..scheduledUnmeteredOnly.clear();
    });
    SetAutoUploadEnabledUseCase usecase() =>
        SetAutoUploadEnabledUseCase(settings, library, backgroundSync, logger);

    test('enables when the library access is granted', () async {
      expect(await usecase().execute(true), isTrue);
      expect(settings.enabled, isTrue);
      expect(backgroundSync.scheduleRequests, 1);
      expect(backgroundSync.cancelRequests, 0);
    });

    test(
      'registers the schedule with the saved connection restriction',
      () async {
        settings.unmeteredOnly = false;
        await usecase().execute(true);
        expect(backgroundSync.scheduledUnmeteredOnly, [false]);
      },
    );

    test('refuses to enable when the user denies photo access', () async {
      library.accessGranted = false;
      expect(await usecase().execute(true), isFalse);
      expect(settings.enabled, isFalse);
      expect(backgroundSync.scheduleRequests, 0);
      expect(backgroundSync.cancelRequests, 1);
    });

    test('disabling never asks for access', () async {
      settings.enabled = true;
      expect(await usecase().execute(false), isFalse);
      expect(settings.enabled, isFalse);
      expect(library.accessRequests, 0);
      expect(backgroundSync.cancelRequests, 1);
    });
  });

  group('auto-upload connection restriction', () {
    final backgroundSync = FakeBackgroundSyncScheduler();
    setUp(() {
      backgroundSync
        ..scheduleRequests = 0
        ..cancelRequests = 0
        ..scheduledUnmeteredOnly.clear();
    });
    SetAutoUploadUnmeteredOnlyUseCase usecase() =>
        SetAutoUploadUnmeteredOnlyUseCase(settings, backgroundSync, logger);

    test('reads the saved value', () {
      settings.unmeteredOnly = false;
      expect(GetAutoUploadUnmeteredOnlyUseCase(settings).execute(), isFalse);
    });

    test(
      're-registers the schedule so the OS honours the new choice',
      () async {
        settings.enabled = true;
        await usecase().execute(false);
        expect(settings.unmeteredOnly, isFalse);
        expect(backgroundSync.scheduledUnmeteredOnly, [false]);
      },
    );

    test('saves without scheduling while auto-upload is off', () async {
      settings.enabled = false;
      await usecase().execute(false);
      expect(settings.unmeteredOnly, isFalse);
      expect(backgroundSync.scheduleRequests, 0);
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
