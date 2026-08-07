import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/photo_upload_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';

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
    this._logger,
  );

  final PhotoLibraryGateway _library;
  final PhotoUploadRepository _uploads;
  final UploadHistoryRepository _history;
  final AppLogger _logger;

  /// [onProgress] fires after each photo settles (uploaded or failed) with
  /// the number of settled photos and the batch size. [cancellation] stops
  /// the batch before the next photo once cancelled.
  Future<UploadPhotosResult> execute(
    List<LocalPhoto> photos, {
    DateTime? uploadedAt,
    void Function(int completed, int total)? onProgress,
    UploadCancellation? cancellation,
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
      await _uploadOne(photo, uploadedAt, uploaded, failed);
      onProgress?.call(uploaded.length + failed.length, photos.length);
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
    List<PhotoUploadFailure> failed,
  ) async {
    final bytes = await _library.readOriginalBytes(photo.localId);
    if (bytes == null) {
      failed.add(
        PhotoUploadFailure(
          photo: photo,
          reason: PhotoUploadFailureReason.missingFromLibrary,
          message: 'Photo is no longer in the device library.',
        ),
      );
      return;
    }
    try {
      await _uploads.upload(photo, bytes);
    } on AppError catch (error) {
      _logger.warning('[Upload] ${photo.fileName} failed: ${error.message}');
      failed.add(
        PhotoUploadFailure(
          photo: photo,
          reason: _reasonFor(error),
          message: error.message,
        ),
      );
      return;
    }
    await _history.markUploaded(photo, uploadedAt ?? DateTime.now().toUtc());
    uploaded.add(photo);
    _logger.info('[Upload] sent ${photo.fileName} (${bytes.length} bytes)');
  }

  static PhotoUploadFailureReason _reasonFor(AppError error) {
    return switch (error) {
      AuthenticationError() => PhotoUploadFailureReason.sessionExpired,
      NetworkUnreachableError() => PhotoUploadFailureReason.unreachable,
      InfrastructureError(code: 'unsupported_format') =>
        PhotoUploadFailureReason.unsupportedFormat,
      _ => PhotoUploadFailureReason.rejected,
    };
  }
}
