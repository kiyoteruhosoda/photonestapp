import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/network_connection_gateway.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/repositories/sync_lease_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';

/// Why a sync pass ended, so the caller can tell "nothing to do" apart from
/// "could not run".
enum SyncSkipReason {
  /// Auto-upload is switched off.
  disabled,

  /// Nobody is signed in, so there is nowhere to upload to.
  notSignedIn,

  /// Auto-upload is restricted to unmetered connections and the device is
  /// on a metered one (or offline).
  meteredConnection,

  /// The user has not granted photo-library access.
  noLibraryAccess,

  /// Another isolate — the background engine or the foreground app — holds
  /// the sync lease and is running a pass right now.
  anotherPassRunning,
}

/// Outcome of one automatic sync pass.
final class SyncReport {
  const SyncReport({this.skipped, this.result});

  const SyncReport.skippedBecause(SyncSkipReason reason)
    : skipped = reason,
      result = null;

  /// Set when the pass did not attempt any upload.
  final SyncSkipReason? skipped;

  /// Set when uploads were attempted (possibly zero, when the library holds
  /// nothing new).
  final UploadPhotosResult? result;

  int get uploadedCount => result?.uploaded.length ?? 0;
}

/// Uploads photos taken since auto-upload was enabled that have not been
/// uploaded yet.
///
/// Runs opportunistically — at startup, when the photo library changes, and
/// when the user toggles the feature — so every precondition is re-checked
/// on each pass instead of being assumed. The whole pass (history read →
/// uploads → history writes) runs under the device-wide sync lease, so the
/// foreground app and the background WorkManager engine never upload the
/// same photo concurrently.
final class SyncNewPhotosUseCase {
  const SyncNewPhotosUseCase(
    this._settings,
    this._sessions,
    this._network,
    this._library,
    this._history,
    this._syncLease,
    this._uploadPhotos,
    this._recordBackupResult,
    this._logger, {
    required this.leaseHolder,
    this.pageSize = 100,
  });

  final AutoUploadSettingsRepository _settings;
  final SessionRepository _sessions;
  final NetworkConnectionGateway _network;
  final PhotoLibraryGateway _library;
  final UploadHistoryRepository _history;
  final SyncLeaseRepository _syncLease;
  final UploadPhotosUseCase _uploadPhotos;
  final RecordBackupResultUseCase _recordBackupResult;
  final AppLogger _logger;

  /// Who this pass runs as when taking the lease — `foreground` for the
  /// app, `background` for the WorkManager engine.
  final String leaseHolder;

  /// How long a pass may hold the lease before a crashed holder stops
  /// blocking everyone else. Long enough for a large batch on a slow
  /// connection; the lease is released the moment the pass ends anyway.
  static const Duration leaseDuration = Duration(minutes: 30);

  /// Window size per library query. Injectable so tests can exercise the
  /// paging without building hundreds of photos.
  final int pageSize;

  Future<SyncReport> execute() async {
    if (!_settings.isEnabled()) {
      return const SyncReport.skippedBecause(SyncSkipReason.disabled);
    }
    if (_sessions.load() == null) {
      return const SyncReport.skippedBecause(SyncSkipReason.notSignedIn);
    }
    // Checked before library access so a pass that is going to be skipped
    // anyway never triggers a permission prompt. The background pass is
    // already gated by the same rule at the scheduler level; this is what
    // stops a photo taken with the app open from going out over mobile data.
    if (_settings.isUnmeteredOnly() && !await _network.isUnmetered()) {
      _logger.info('[AutoUpload] connection is metered — skipping this pass');
      return const SyncReport.skippedBecause(SyncSkipReason.meteredConnection);
    }
    if (!await _library.ensureAccess()) {
      _logger.warning('[AutoUpload] photo library access not granted');
      return const SyncReport.skippedBecause(SyncSkipReason.noLibraryAccess);
    }

    final now = DateTime.now().toUtc();
    final acquired = await _syncLease.tryAcquire(
      leaseHolder,
      until: now.add(leaseDuration),
      now: now,
    );
    if (!acquired) {
      _logger.info('[AutoUpload] sync lease busy — skipping this pass');
      return const SyncReport.skippedBecause(SyncSkipReason.anotherPassRunning);
    }
    try {
      return await _runPass();
    } finally {
      await _syncLease.release(leaseHolder);
    }
  }

  Future<SyncReport> _runPass() async {
    final since = _settings.enabledSince();
    final uploaded = await _history.uploadedLocalIds();
    // Page through the whole window after `since`: the library answers
    // newest-first, so stopping at the first page would revisit the same
    // already-uploaded photos forever once more than one page had
    // accumulated, and the older ones would never be examined.
    final pending = <LocalPhoto>[];
    for (var page = 0; ; page++) {
      final batch = await _library.photosTakenAfter(
        since,
        limit: pageSize,
        page: page,
      );
      pending.addAll(batch.where((photo) => !uploaded.contains(photo.localId)));
      if (batch.length < pageSize) break;
    }
    if (pending.isEmpty) {
      return const SyncReport(
        result: UploadPhotosResult(uploaded: [], failed: []),
      );
    }

    _logger.info('[AutoUpload] found ${pending.length} new photo(s)');
    final result = await _uploadPhotos.execute(pending);
    // Recorded from inside the pass so both isolates — foreground app and
    // background WorkManager engine — leave the same trace in the list.
    await _recordBackupResult.execute(
      uploadedCount: result.uploaded.length,
      failedCount: result.failed.length,
    );
    return SyncReport(result: result);
  }
}
