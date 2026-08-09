import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/network_connection_gateway.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:photonest/application/usecases/upload/upload_photos_usecase.dart';
import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/sync_lease_repository.dart';
import 'package:photonest/domain/repositories/upload_history_repository.dart';
import 'package:photonest/domain/value_objects/media_permission.dart';

/// Why a sync pass ended, so the caller can tell "nothing to do" apart from
/// "could not run".
enum SyncSkipReason {
  /// Auto-upload is switched off.
  disabled,

  /// Nobody is signed in, so there is nowhere to upload to.
  notSignedIn,

  /// The signed-in session holds no upload permission, so the server would
  /// refuse every photo this pass sent.
  notPermitted,

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
    final session = _sessions.load();
    if (session == null) {
      return const SyncReport.skippedBecause(SyncSkipReason.notSignedIn);
    }
    // Checked here rather than only in the UI: this pass runs unwatched — at
    // launch, on every library change, and from the background engine — so a
    // session that lost `media:upload` would keep sending photos the server
    // can only refuse, recording each 403 as a failure the reader never asked
    // for. The upload screen is hidden from such a session, which is exactly
    // why the automatic path cannot rely on it.
    if (!GrantedPermissions.of(session).allows(MediaPermission.uploadMedia)) {
      _logger.warning('[AutoUpload] session may not upload — skipping');
      return const SyncReport.skippedBecause(SyncSkipReason.notPermitted);
    }
    // Checked before library access so a pass that is going to be skipped
    // anyway never triggers a permission prompt. The background pass is
    // already gated by the same rule at the scheduler level; this is what
    // stops a photo taken with the app open from going out over mobile data.
    if (!await _mayUploadOverCurrentConnection()) {
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

  /// Whether the batch this pass started may keep going.
  ///
  /// Re-checked before every photo, because a pass over originals can run
  /// for many minutes: both the connection and the backup target can change
  /// while it does. Photos left unattempted stay unrecorded, so the next
  /// pass — the one the coordinator runs as soon as this one ends — picks
  /// up whatever the new choice actually asks for.
  Future<bool> _mayContinueSending(Set<String> targetWhenPassStarted) async {
    if (!_targetStillMatches(targetWhenPassStarted)) {
      _logger.info('[AutoUpload] backup target changed — stopping this batch');
      return false;
    }
    return _mayUploadOverCurrentConnection();
  }

  /// Whether the persisted backup target is still the one this pass planned
  /// against. A narrowed target must not keep sending what it excluded.
  bool _targetStillMatches(Set<String> targetWhenPassStarted) {
    final current = _settings.backupAlbumIds();
    return current.length == targetWhenPassStarted.length &&
        current.containsAll(targetWhenPassStarted);
  }

  /// Whether the connection the device is on right now is one auto-upload is
  /// allowed to spend. Both the setting and the connection are re-read on
  /// every call, so neither is captured at the start of a pass.
  Future<bool> _mayUploadOverCurrentConnection() async {
    if (!_settings.isUnmeteredOnly()) return true;
    if (await _network.isUnmetered()) return true;
    _logger.info('[AutoUpload] connection is metered — not uploading');
    return false;
  }

  Future<SyncReport> _runPass() async {
    final since = _settings.enabledSince();
    final uploaded = await _history.uploadedLocalIds();
    // An empty selection means the whole library — queried as a single
    // pass over the platform's "everything" bucket rather than as every
    // album, so the default costs exactly what it did before. Copied so the
    // comparison below cannot be defeated by a repository that hands back
    // the same mutable set it stores.
    final selectedAlbumIds = {..._settings.backupAlbumIds()};
    final targets = selectedAlbumIds.isEmpty
        ? const <String?>[null]
        : selectedAlbumIds.toList();

    // Page through the whole window after `since`: the library answers
    // newest-first, so stopping at the first page would revisit the same
    // already-uploaded photos forever once more than one page had
    // accumulated, and the older ones would never be examined.
    final pending = <LocalPhoto>[];
    // The same asset can sit in more than one selected album, and would
    // otherwise be sent twice within a single pass — the upload history is
    // only written once the pass is over, so it cannot catch that.
    final seen = <String>{};
    for (final albumId in targets) {
      for (var page = 0; ; page++) {
        final batch = await _library.photosTakenAfter(
          since,
          limit: pageSize,
          page: page,
          albumId: albumId,
        );
        for (final photo in batch) {
          if (uploaded.contains(photo.localId)) continue;
          if (!seen.add(photo.localId)) continue;
          pending.add(photo);
        }
        if (batch.length < pageSize) break;
      }
    }
    if (pending.isEmpty) {
      return const SyncReport(
        result: UploadPhotosResult(uploaded: [], failed: []),
      );
    }

    _logger.info('[AutoUpload] found ${pending.length} new photo(s)');
    // Re-checked before every photo rather than once for the batch: sending
    // originals can take many minutes, in which time the device can leave
    // Wi-Fi — or the user can switch the restriction on — and the rest of the
    // batch would otherwise keep going out over mobile data. Photos left
    // unattempted stay unrecorded, so the next pass picks them up.
    final result = await _uploadPhotos.execute(
      pending,
      mayContinue: () => _mayContinueSending(selectedAlbumIds),
      // Every pass through here is automatic, whichever isolate runs it —
      // the foreground coordinator's passes are just as unwatched as the
      // background engine's.
      automatic: true,
    );
    // Recorded from inside the pass so both isolates — foreground app and
    // background WorkManager engine — leave the same trace in the list.
    await _recordBackupResult.execute(
      uploadedCount: result.uploaded.length,
      failedCount: result.failed.length,
    );
    return SyncReport(result: result);
  }
}
