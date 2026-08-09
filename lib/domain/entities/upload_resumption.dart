import 'package:photonest/domain/errors/app_error.dart';

/// Where a chunked upload of one device photo got to, so a later run can
/// carry on instead of sending the file again from the start.
///
/// The server identifies a part-received file by the pair
/// ([uploadSessionId], [tempFileId]) — the session is the client-generated
/// id both calls carry, the temp file id is what the server handed back when
/// the upload began. Neither can be recomputed, so both have to be
/// remembered for the resume to be possible at all.
///
/// [fileSize] is remembered too: an asset the device re-encoded (or a
/// different photo that reused the id) is not the file the server is holding
/// bytes for, and appending to it would produce a corrupt upload.
///
/// Identity is the [localId] — one device photo has at most one upload in
/// flight.
final class UploadResumption {
  /// Throws [DomainError] when a field that the resume depends on is blank
  /// or non-positive — a record that cannot address the server's temp file
  /// is worse than no record, because it would be trusted.
  factory UploadResumption({
    required String localId,
    required String fileName,
    required int fileSize,
    required String uploadSessionId,
    required String tempFileId,
  }) {
    if (localId.trim().isEmpty) {
      throw const DomainError('UploadResumption needs the photo id.');
    }
    if (uploadSessionId.trim().isEmpty || tempFileId.trim().isEmpty) {
      throw const DomainError(
        'UploadResumption needs both the upload session and the temp file id.',
      );
    }
    if (fileSize <= 0) {
      throw const DomainError('UploadResumption needs a positive file size.');
    }
    return UploadResumption._(
      localId: localId,
      fileName: fileName,
      fileSize: fileSize,
      uploadSessionId: uploadSessionId,
      tempFileId: tempFileId,
    );
  }

  const UploadResumption._({
    required this.localId,
    required this.fileName,
    required this.fileSize,
    required this.uploadSessionId,
    required this.tempFileId,
  });

  /// Platform asset identifier of the photo being uploaded.
  final String localId;

  /// Name the file was announced under. Kept so a renamed asset is not
  /// appended to the wrong upload.
  final String fileName;

  /// Total size in bytes the upload was announced with.
  final int fileSize;

  /// The `X-Upload-Session` value both the append and the commit must carry.
  final String uploadSessionId;

  /// The server's handle for the part-received file.
  final String tempFileId;

  /// Whether this record describes the same file as a fresh upload of
  /// [fileName] at [fileSize] would.
  ///
  /// A mismatch means the asset changed under us; the caller starts over
  /// rather than appending to bytes that belong to something else.
  bool describes({required String fileName, required int fileSize}) =>
      this.fileName == fileName && this.fileSize == fileSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadResumption && other.localId == localId);

  @override
  int get hashCode => localId.hashCode;

  @override
  String toString() =>
      'UploadResumption($localId, $tempFileId, $fileSize bytes)';
}
