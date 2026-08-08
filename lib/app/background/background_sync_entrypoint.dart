import 'package:flutter/widgets.dart';
import 'package:flutterbase/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/infrastructure/infrastructure_module.dart';
import 'package:workmanager/workmanager.dart';

/// WorkManager's entry into the app while it is closed.
///
/// The platform launches a headless Flutter engine and calls this function,
/// so it is a composition root of its own: it assembles the same adapters
/// and use cases `setupServiceLocator` would, runs one auto-upload sync
/// pass, and exits. `@pragma('vm:entry-point')` keeps tree-shaking from
/// stripping it — nothing in the foreground app calls it.
///
/// The sync pass re-checks every precondition itself (feature on, signed
/// in, library access), so a wake-up with nothing to do is a cheap no-op.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final infrastructure = await InfrastructureModule.create(
      backgroundSyncDispatcher: backgroundSyncDispatcher,
    );
    final logger = infrastructure.appLogger;
    logger.info('[Background] sync task started ($taskName)');
    try {
      final syncNewPhotos = SyncNewPhotosUseCase(
        infrastructure.autoUploadSettings,
        infrastructure.sessions,
        infrastructure.networkConnection,
        infrastructure.photoLibrary,
        infrastructure.uploadHistory,
        infrastructure.syncLease,
        UploadPhotosUseCase(
          infrastructure.photoLibrary,
          infrastructure.photoUploads,
          infrastructure.uploadHistory,
          infrastructure.uploadFailures,
          logger,
        ),
        RecordBackupResultUseCase(infrastructure.backupNotifications, logger),
        logger,
        leaseHolder: 'background',
      );
      final report = await syncNewPhotos.execute();
      final outcome = report.skipped != null
          ? 'skipped (${report.skipped!.name})'
          : '${report.uploadedCount} uploaded';
      logger.info('[Background] sync task done — $outcome');
      // Success even when photos failed: per-photo failures are already
      // recorded, and the next periodic run retries them anyway — an OS-level
      // retry with backoff would only drain the battery faster.
      return true;
    } on Exception catch (error, stackTrace) {
      // Only an unexpected failure of the pass itself lands here; asking the
      // OS to retry with backoff is the right response to those.
      logger.error(
        '[Background] sync task failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}
