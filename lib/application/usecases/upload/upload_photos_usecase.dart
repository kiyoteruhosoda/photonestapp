import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/entities/upload_failure.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/photo_upload_repository.dart';
import 'package:photonest/domain/repositories/upload_failure_repository.dart';
import 'package:photonest/domain/repositories/upload_history_repository.dart';

/// Why a single photo could not be uploaded, as something the UI can
/// translate — the developer-facing detail stays in
/// [PhotoUploadFailure.message] for the logs.
enum PhotoUploadFailureReason {
  /// The asset vanished from the device library between listing and upload.
  missingFromLibrary,

  /// The file type is one the server does not accept.
  unsupportedFormat,

  /// The session expired and could not be refreshed.
  sessionExpired,

  /// The server could not be reached — retrying once connected may succeed.
  unreachable,

  /// The server answered and refused the photo.
  rejected,
}

/// One photo that could not be uploaded, with the reason.
final class PhotoUploadFailure {
  const PhotoUploadFailure({
    required this.photo,
    required this.reason,
    required this.message,
  });

  final LocalPhoto photo;
  final PhotoUploadFailureReason reason;

  /// Developer-facing detail for the logs; never shown to the user verbatim.
  final String message;

  @override
  String toString() =>
      'PhotoUploadFailure(${photo.localId}: ${reason.name} — $message)';
}

/// How far a batch has got: which photo is in flight, and how much of it
/// has been sent.
///
/// The per-photo byte counts matter because a batch can be one long video:
/// counting settled photos alone leaves the bar frozen for minutes.
final class UploadProgress {
  const UploadProgress({
    required this.completed,
    required this.total,
    required this.fileName,
    this.sentBytes = 0,
    this.totalBytes = 0,
  });

  /// Photos settled so far (uploaded or failed).
  final int completed;

  /// Batch size.
  final int total;

  /// The photo currently being sent.
  final String fileName;

  /// Bytes of [fileName] handed to the network so far.
  final int sentBytes;

  /// Size of [fileName] in bytes, or 0 while it is unknown.
  final int totalBytes;

  /// How far the whole batch has got, 0…1 — settled photos plus the
  /// fraction of the one in flight, so a single large file still moves the
  /// bar.
  double get fraction {
    if (total == 0) return 0;
    final inFlight = totalBytes == 0 ? 0.0 : sentBytes / totalBytes;
    return ((completed + inFlight) / total).clamp(0.0, 1.0);
  }
}

/// Cooperative cancellation flag for an upload batch.
///
/// The caller holds on to it and calls [cancel]; the running batch checks
/// [requested] before each photo, so the photo currently in flight still
/// completes — an upload is not something to abort halfway through.
final class UploadCancellation {
  bool _requested = false;

  /// Whether [cancel] has been called.
  bool get requested => _requested;

  /// Asks the running batch to stop before the next photo.
  void cancel() => _requested = true;
}

/// Outcome of an upload batch.
final class UploadPhotosResult {
  const UploadPhotosResult({
    required this.uploaded,
    required this.failed,
    this.cancelled = false,
  });

  final List<LocalPhoto> uploaded;
  final List<PhotoUploadFailure> failed;

  /// True when the batch stopped early because the caller cancelled it.
  /// Photos not attempted appear in neither [uploaded] nor [failed].
  final bool cancelled;

  bool get hasFailures => failed.isNotEmpty;
}

/// Uploads a batch of device photos and records each success in the history.
///
/// Photos are sent one at a time so a single failure does not poison the
/// batch: everything that succeeded stays uploaded and marked, and the
/// failures come back with their reasons.
final class UploadPhotosUseCase {
  const UploadPhotosUseCase(
    this._library,
    this._uploads,
    this._history,
    this._failures,
    this._logger,
  );

  final PhotoLibraryGateway _library;
  final PhotoUploadRepository _uploads;
  final UploadHistoryRepository _history;
  final UploadFailureRepository _failures;
  final AppLogger _logger;

  /// [onProgress] fires as the batch advances — once per byte-progress
  /// report from the photo in flight, and once more as each photo settles.
  /// [cancellation] stops the batch before the next photo once cancelled.
  ///
  /// [automatic] marks the batch as coming from a background pass rather
  /// than a manual upload; it is recorded with each failure so the list can
  /// say a photo failed while nobody was watching. It belongs to the call
  /// rather than to the instance — the same use case serves both paths, and
  /// a constructor flag would silently be wrong for whichever composition
  /// root forgot it.
  ///
  /// [mayContinue] is awaited before each photo and stops the batch when it
  /// answers false. It exists for preconditions that can stop holding
  /// part-way through: a batch of originals can take many minutes, so a
  /// caller that only checked once before the first photo would keep sending
  /// long after its condition went away.
  Future<UploadPhotosResult> execute(
    List<LocalPhoto> photos, {
    DateTime? uploadedAt,
    void Function(UploadProgress progress)? onProgress,
    UploadCancellation? cancellation,
    Future<bool> Function()? mayContinue,
    bool automatic = false,
  }) async {
    final uploaded = <LocalPhoto>[];
    final failed = <PhotoUploadFailure>[];
    var cancelled = false;

    for (final photo in photos) {
      if (cancellation?.requested ?? false) {
        cancelled = true;
        _logger.info(
          '[Upload] batch cancelled after ${uploaded.length + failed.length} '
          'of ${photos.length}',
        );
        break;
      }
      if (mayContinue != null && !await mayContinue()) {
        cancelled = true;
        _logger.info(
          '[Upload] batch stopped after ${uploaded.length + failed.length} '
          'of ${photos.length} — the caller withdrew permission to continue',
        );
        break;
      }
      final settled = uploaded.length + failed.length;
      await _uploadOne(
        photo,
        uploadedAt,
        uploaded,
        failed,
        automatic: automatic,
        onBytes: onProgress == null
            ? null
            : (sent, total) => onProgress(
                UploadProgress(
                  completed: settled,
                  total: photos.length,
                  fileName: photo.fileName,
                  sentBytes: sent,
                  totalBytes: total,
                ),
              ),
      );
      onProgress?.call(
        UploadProgress(
          completed: uploaded.length + failed.length,
          total: photos.length,
          fileName: photo.fileName,
        ),
      );
    }

    _logger.info(
      '[Upload] batch done — ${uploaded.length} sent, ${failed.length} failed',
    );
    return UploadPhotosResult(
      uploaded: uploaded,
      failed: failed,
      cancelled: cancelled,
    );
  }

  Future<void> _uploadOne(
    LocalPhoto photo,
    DateTime? uploadedAt,
    List<LocalPhoto> uploaded,
    List<PhotoUploadFailure> failed, {
    required bool automatic,
    UploadBytesProgress? onBytes,
  }) async {
    try {
      await _sendOriginal(photo, onBytes);
    } on _AssetVanished {
      await _recordFailure(
        photo,
        PhotoUploadFailureReason.missingFromLibrary,
        'Photo is no longer in the device library.',
        failed,
        automatic: automatic,
      );
      return;
    } on AppError catch (error) {
      _logger.warning('[Upload] ${photo.fileName} failed: ${error.message}');
      await _recordFailure(
        photo,
        _reasonFor(error),
        error.message,
        failed,
        automatic: automatic,
      );
      return;
    }
    await _history.markUploaded(photo, uploadedAt ?? DateTime.now().toUtc());
    uploaded.add(photo);
    _logger.info('[Upload] sent ${photo.fileName}');
    // A photo that finally went through is no longer a live problem, so its
    // record goes away rather than lingering in the failure list forever.
    // Swallowed like the write below: the server has already accepted the
    // file, and aborting the batch over a bookkeeping row would strand the
    // rest of it — and invite a re-upload of what just succeeded.
    try {
      await _failures.clear(photo.localId);
    } on AppError catch (error) {
      _logger.warning('[Upload] could not clear the failure record: $error');
    }
  }

  /// Adds the failure to the batch's list and to the durable record.
  ///
  /// Persisting is what makes a background pass's failures nameable after a
  /// restart. A store that cannot be written is logged and swallowed: the
  /// batch's own outcome is the more important answer, and failing the run
  /// over a bookkeeping row would be worse than losing the row.
  Future<void> _recordFailure(
    LocalPhoto photo,
    PhotoUploadFailureReason reason,
    String message,
    List<PhotoUploadFailure> failed, {
    required bool automatic,
  }) async {
    failed.add(
      PhotoUploadFailure(photo: photo, reason: reason, message: message),
    );
    try {
      await _failures.record(
        photo: photo,
        reason: _persistedReasonFor(reason),
        message: message,
        automatic: automatic,
        failedAt: DateTime.now().toUtc(),
      );
    } on AppError catch (error) {
      _logger.warning('[Upload] could not record the failure: $error');
    }
  }

  static UploadFailureReason _persistedReasonFor(
    PhotoUploadFailureReason reason,
  ) {
    return switch (reason) {
      PhotoUploadFailureReason.missingFromLibrary =>
        UploadFailureReason.missingFromLibrary,
      PhotoUploadFailureReason.unsupportedFormat =>
        UploadFailureReason.unsupportedFormat,
      PhotoUploadFailureReason.sessionExpired =>
        UploadFailureReason.sessionExpired,
      PhotoUploadFailureReason.unreachable => UploadFailureReason.unreachable,
      PhotoUploadFailureReason.rejected => UploadFailureReason.rejected,
    };
  }

  /// Streams the original from its file when the platform exposes one —
  /// what keeps a long video out of the app heap — and falls back to an
  /// in-memory read otherwise. Throws [_AssetVanished] when the asset is
  /// gone from the library either way.
  Future<void> _sendOriginal(
    LocalPhoto photo,
    UploadBytesProgress? onBytes,
  ) async {
    final path = await _library.originalFilePath(photo.localId);
    if (path != null) {
      try {
        await _uploads.uploadFromPath(photo, path, onBytes: onBytes);
        return;
      } on InfrastructureError catch (error) {
        if (error.code != 'missing_file') rethrow;
        throw const _AssetVanished();
      }
    }
    final bytes = await _library.readOriginalBytes(photo.localId);
    if (bytes == null) throw const _AssetVanished();
    await _uploads.upload(photo, bytes, onBytes: onBytes);
  }

  static PhotoUploadFailureReason _reasonFor(AppError error) {
    return switch (error) {
      AuthenticationError() => PhotoUploadFailureReason.sessionExpired,
      NetworkUnreachableError() => PhotoUploadFailureReason.unreachable,
      InfrastructureError(code: 'unsupported_format') =>
        PhotoUploadFailureReason.unsupportedFormat,
      // A chunked upload that stopped making progress is a transfer that
      // failed, not a photo the server refused: the next pass resumes it
      // from where it stopped and will usually finish. Calling it "rejected"
      // would tell the reader to give up on a photo that is fine.
      InfrastructureError(code: 'upload_stalled') =>
        PhotoUploadFailureReason.unreachable,
      _ => PhotoUploadFailureReason.rejected,
    };
  }
}

/// Internal signal that the asset disappeared between listing and upload.
final class _AssetVanished implements Exception {
  const _AssetVanished();
}
