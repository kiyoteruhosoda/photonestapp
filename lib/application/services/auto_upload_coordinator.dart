import 'dart:async';

import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/background_sync_scheduler.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';

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
  bool _pokedWhileRunning = false;

  /// Runs one initial pass and starts watching the library. Idempotent.
  void start() {
    if (_subscription != null) return;
    _logger.info('[AutoUpload] coordinator started');
    _subscription = _library.libraryChanges.listen(_onLibraryChanged);
    // Re-asserts the background schedule at every launch: an app update or a
    // cleared task list must not silently end background syncing the user
    // switched on. The toggle use case owns changes; this only repairs.
    if (_settings.isEnabled()) {
      unawaited(
        _backgroundSync.ensureScheduled(
          unmeteredOnly: _settings.isUnmeteredOnly(),
        ),
      );
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

  /// Runs one sync pass, never two at once.
  ///
  /// Overlap protection matters: a pass can take a long time on a slow
  /// connection, and a second concurrent pass would upload the same photos —
  /// the history is only written after each successful upload.
  ///
  /// A poke that arrives during a pass is **not** dropped, though. A running
  /// pass took its preconditions — which albums to read, whether Wi-Fi is
  /// required — when it started, so it cannot answer a choice made since;
  /// dropping the poke would leave that choice unapplied until the next
  /// library change. The poke is remembered and one more pass runs when the
  /// current one ends.
  Future<void> triggerSync() async {
    if (_syncing) {
      _pokedWhileRunning = true;
      return;
    }
    _syncing = true;
    try {
      do {
        // Cleared before the pass, not after: a poke that lands while this
        // pass runs must survive into the next iteration.
        _pokedWhileRunning = false;
        final report = await _syncNewPhotos.execute();
        if (report.uploadedCount > 0) {
          _logger.info(
            '[AutoUpload] pass uploaded ${report.uploadedCount} photo(s)',
          );
        }
      } while (_pokedWhileRunning);
    } finally {
      _syncing = false;
      _pokedWhileRunning = false;
    }
  }
}
