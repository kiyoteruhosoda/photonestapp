import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/services/auto_upload_coordinator.dart';
import 'package:flutterbase/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

void main() {
  late FakePhotoLibraryGateway library;
  late FakeUploadHistoryRepository history;
  late FakeUploadFailureRepository failures;
  late FakePhotoUploadRepository uploads;
  late FakeAutoUploadSettingsRepository settings;
  late FakeSessionRepository sessions;
  late FakeNetworkConnectionGateway network;
  late FakeBackgroundSyncScheduler backgroundSync;
  late FakeSyncLeaseRepository syncLease;
  late FakeBackupNotificationRepository notifications;
  late RecordingAppLogger logger;

  setUp(() {
    library = FakePhotoLibraryGateway();
    history = FakeUploadHistoryRepository();
    failures = FakeUploadFailureRepository();
    uploads = FakePhotoUploadRepository();
    settings = FakeAutoUploadSettingsRepository(
      enabled: true,
      since: DateTime.utc(2026, 8, 1),
    );
    sessions = FakeSessionRepository(testAuthSession);
    network = FakeNetworkConnectionGateway();
    backgroundSync = FakeBackgroundSyncScheduler();
    syncLease = FakeSyncLeaseRepository();
    notifications = FakeBackupNotificationRepository();
    logger = RecordingAppLogger();
  });

  AutoUploadCoordinator coordinator({Duration debounce = Duration.zero}) {
    return AutoUploadCoordinator(
      library,
      SyncNewPhotosUseCase(
        settings,
        sessions,
        network,
        library,
        history,
        syncLease,
        UploadPhotosUseCase(library, uploads, history, failures, logger),
        RecordBackupResultUseCase(notifications, logger),
        logger,
        leaseHolder: 'foreground',
      ),
      settings,
      backgroundSync,
      logger,
      debounce: debounce,
    );
  }

  void seed(String id) {
    final photo = testLocalPhoto(
      localId: id,
      takenAt: DateTime.utc(2026, 8, 2),
    );
    library.photos = [...library.photos, photo];
    library.bytesById[id] = Uint8List.fromList([1]);
  }

  test('start runs an initial sync pass', () async {
    seed('first');
    final subject = coordinator()..start();
    addTearDown(subject.stop);

    await pumpEventQueue();
    expect(uploads.uploaded, hasLength(1));
  });

  test('start re-asserts the background schedule while enabled', () async {
    settings.unmeteredOnly = false;
    final subject = coordinator()..start();
    addTearDown(subject.stop);

    await pumpEventQueue();
    expect(backgroundSync.scheduleRequests, 1);
    // The repaired registration carries the user's current choice, not the
    // one the schedule happened to be registered with.
    expect(backgroundSync.scheduledUnmeteredOnly, [false]);
  });

  test('a library change on a metered connection uploads nothing', () async {
    network.unmetered = false;
    final subject = coordinator()..start();
    addTearDown(subject.stop);
    await pumpEventQueue();

    seed('new-photo');
    library.changes.add(null);
    await pumpEventQueue(times: 50);

    expect(uploads.uploaded, isEmpty);
  });

  test('start leaves the background schedule alone while disabled', () async {
    settings.enabled = false;
    final subject = coordinator()..start();
    addTearDown(subject.stop);

    await pumpEventQueue();
    expect(backgroundSync.scheduleRequests, 0);
  });

  test('a library change triggers another pass after the debounce', () async {
    final subject = coordinator()..start();
    addTearDown(subject.stop);
    await pumpEventQueue();
    expect(uploads.uploaded, isEmpty);

    seed('new-photo');
    library.changes.add(null);
    await pumpEventQueue(times: 50);

    expect(uploads.uploaded, hasLength(1));
  });

  test(
    'start is idempotent — a second call adds no second subscription', //
    () async {
      final subject = coordinator()
        ..start()
        ..start();
      addTearDown(subject.stop);
      await pumpEventQueue();
      expect(library.changes.hasListener, isTrue);
    },
  );

  test('stop cancels the subscription', () async {
    final subject = coordinator()..start();
    await pumpEventQueue();
    await subject.stop();
    expect(library.changes.hasListener, isFalse);
  });

  test('overlapping triggers run one pass at a time', () async {
    seed('only');
    final subject = coordinator();
    addTearDown(subject.stop);

    await Future.wait([subject.triggerSync(), subject.triggerSync()]);

    // A second concurrent pass would have uploaded the photo twice: the
    // history is only written once an upload finishes.
    expect(uploads.uploaded, hasLength(1));
  });
}
