import 'dart:async';

import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';

/// Keeps the automatic upload running while the app is alive.
///
/// Listens to the photo library's change stream and runs a sync pass after
/// each burst of changes. The pass itself re-checks every precondition
/// (feature enabled, signed in, access granted), so this class can stay
/// subscribed unconditionally — a change event while auto-upload is off
/// costs one cheap early return.
final class AutoUploadCoordinator {
  AutoUploadCoordinator(
    this._library,
    this._syncNewPhotos,
    this._settings,
    this._backgroundSync,
    this._logger, {
    Duration debounce = const Duration(seconds: 5),
  }) : _debounceDuration = debounce;

  final PhotoLibraryGateway _library;
  final SyncNewPhotosUseCase _syncNewPhotos;
  final AutoUploadSettingsRepository _settings;
  final BackgroundSyncScheduler _backgroundSync;
  final AppLogger _logger;
  final Duration _debounceDuration;

  StreamSubscription<void>? _subscription;
  Timer? _debounce;
  bool _syncing = false;

  /// Runs one initial pass and starts watching the library. Idempotent.
  void start() {
    if (_subscription != null) return;
    _logger.info('[AutoUpload] coordinator started');
    _subscription = _library.libraryChanges.listen(_onLibraryChanged);
    // Re-asserts the background schedule at every launch: an app update or a
    // cleared task list must not silently end background syncing the user
    // switched on. The toggle use case owns changes; this only repairs.
    if (_settings.isEnabled()) {
      unawaited(_backgroundSync.ensureScheduled());
    }
    unawaited(triggerSync());
  }

  /// Stops watching. Safe to call when not started.
  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Debounced: photo captures often produce several change events in quick
  /// succession, and one pass after the burst uploads them all.
  void _onLibraryChanged(void _) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => unawaited(triggerSync()));
  }

  /// Runs one sync pass, unless one is already running.
  ///
  /// Overlap protection matters: a pass can take a long time on a slow
  /// connection, and a second concurrent pass would upload the same photos —
  /// the history is only written after each successful upload.
  Future<void> triggerSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final report = await _syncNewPhotos.execute();
      if (report.uploadedCount > 0) {
        _logger.info(
          '[AutoUpload] pass uploaded ${report.uploadedCount} photo(s)',
        );
      }
    } finally {
      _syncing = false;
    }
  }
}
