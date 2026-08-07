import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/photo_upload_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';

/// One photo that could not be uploaded, with the reason.
final class PhotoUploadFailure {
  const PhotoUploadFailure({required this.photo, required this.message});

  final LocalPhoto photo;
  final String message;

  @override
  String toString() => 'PhotoUploadFailure(${photo.localId}: $message)';
}

/// Outcome of an upload batch.
final class UploadPhotosResult {
  const UploadPhotosResult({required this.uploaded, required this.failed});

  final List<LocalPhoto> uploaded;
  final List<PhotoUploadFailure> failed;

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

  Future<UploadPhotosResult> execute(
    List<LocalPhoto> photos, {
    DateTime? uploadedAt,
  }) async {
    final uploaded = <LocalPhoto>[];
    final failed = <PhotoUploadFailure>[];

    for (final photo in photos) {
      final bytes = await _library.readOriginalBytes(photo.localId);
      if (bytes == null) {
        failed.add(
          PhotoUploadFailure(
            photo: photo,
            message: 'Photo is no longer in the device library.',
          ),
        );
        continue;
      }
      try {
        await _uploads.upload(photo, bytes);
      } on AppError catch (error) {
        _logger.warning('[Upload] ${photo.fileName} failed: ${error.message}');
        failed.add(PhotoUploadFailure(photo: photo, message: error.message));
        continue;
      }
      await _history.markUploaded(photo, uploadedAt ?? DateTime.now().toUtc());
      uploaded.add(photo);
      _logger.info('[Upload] sent ${photo.fileName} (${bytes.length} bytes)');
    }

    _logger.info(
      '[Upload] batch done — ${uploaded.length} sent, ${failed.length} failed',
    );
    return UploadPhotosResult(uploaded: uploaded, failed: failed);
  }
}
