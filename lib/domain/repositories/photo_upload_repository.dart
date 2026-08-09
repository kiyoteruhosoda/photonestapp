import 'dart:typed_data';

import 'package:photonest/domain/entities/local_photo.dart';

/// How far one file's bytes have travelled: [sent] of [total].
///
/// [total] is 0 when the size is not known up front, which a progress bar
/// reads as "indeterminate".
typedef UploadBytesProgress = void Function(int sent, int total);

/// Boundary to the server's upload endpoints.
abstract interface class PhotoUploadRepository {
  /// Uploads [bytes] as [photo]'s content.
  ///
  /// Completes when the server has accepted the file into its import queue —
  /// the photo becomes visible in the library once the server-side import
  /// job has processed it. Throws `AuthenticationError` when the session is
  /// invalid and `InfrastructureError` when the upload is rejected or the
  /// server cannot be reached.
  ///
  /// [onBytes] reports the send as it happens. A single video can take
  /// minutes, and without it a per-photo bar looks frozen for the whole
  /// upload.
  Future<void> upload(
    LocalPhoto photo,
    Uint8List bytes, {
    UploadBytesProgress? onBytes,
  });

  /// Uploads the file at [path] as [photo]'s content, streaming it from
  /// disk so even a long video never sits in memory whole.
  ///
  /// Same completion and error contract as [upload]; additionally throws
  /// `InfrastructureError` with code `missing_file` when the file has
  /// vanished from [path].
  Future<void> uploadFromPath(
    LocalPhoto photo,
    String path, {
    UploadBytesProgress? onBytes,
  });
}
