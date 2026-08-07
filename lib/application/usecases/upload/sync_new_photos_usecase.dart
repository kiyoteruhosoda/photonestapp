import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';

/// Why a sync pass ended, so the caller can tell "nothing to do" apart from
/// "could not run".
enum SyncSkipReason {
  /// Auto-upload is switched off.
  disabled,

  /// Nobody is signed in, so there is nowhere to upload to.
  notSignedIn,

  /// The user has not granted photo-library access.
  noLibraryAccess,
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
/// on each pass instead of being assumed.
final class SyncNewPhotosUseCase {
  const SyncNewPhotosUseCase(
    this._settings,
    this._sessions,
    this._library,
    this._history,
    this._uploadPhotos,
    this._logger, {
    this.pageSize = 100,
  });

  final AutoUploadSettingsRepository _settings;
  final SessionRepository _sessions;
  final PhotoLibraryGateway _library;
  final UploadHistoryRepository _history;
  final UploadPhotosUseCase _uploadPhotos;
  final AppLogger _logger;

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
    if (!await _library.ensureAccess()) {
      _logger.warning('[AutoUpload] photo library access not granted');
      return const SyncReport.skippedBecause(SyncSkipReason.noLibraryAccess);
    }

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
    return SyncReport(result: result);
  }
}
