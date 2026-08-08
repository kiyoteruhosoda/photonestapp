import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

/// [BackgroundSyncScheduler] backed by the `workmanager` plugin — Android's
/// WorkManager behind a Flutter API.
///
/// The [dispatcher] is the composition root's background entry point: the
/// platform launches a headless Flutter engine and runs it, so it must be a
/// top-level `@pragma('vm:entry-point')` function. This adapter only owns
/// the scheduling calls; what a sync pass does lives with the entry point.
final class WorkmanagerBackgroundSyncScheduler
    implements BackgroundSyncScheduler {
  WorkmanagerBackgroundSyncScheduler(this._dispatcher);

  /// Name WorkManager deduplicates registrations by.
  static const String uniqueName = 'auto-upload-sync';

  /// Name delivered back to the dispatcher when the task runs.
  static const String taskName = 'auto-upload-sync';

  final void Function() _dispatcher;
  bool _initialized = false;

  @override
  Future<void> ensureScheduled() async {
    await _ensureInitialized();
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      // 15 minutes is WorkManager's floor; the OS batches wake-ups anyway,
      // so asking for less would only be rounded up.
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        // Uploads are pointless offline, and skipping low-battery windows is
        // what keeps the feature invisible on the battery stats page.
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      // Keep the existing registration: replacing would reset WorkManager's
      // scheduling state on every app start for no behavioural difference.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancel() async {
    await _ensureInitialized();
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Workmanager().initialize(_dispatcher);
    _initialized = true;
  }
}
