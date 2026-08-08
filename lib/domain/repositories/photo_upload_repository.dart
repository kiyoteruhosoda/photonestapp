import 'dart:typed_data';

import 'package:flutterbase/domain/entities/local_photo.dart';

/// Boundary to the server's upload endpoints.
abstract interface class PhotoUploadRepository {
  /// Uploads [bytes] as [photo]'s content.
  ///
  /// Completes when the server has accepted the file into its import queue —
  /// the photo becomes visible in the library once the server-side import
  /// job has processed it. Throws `AuthenticationError` when the session is
  /// invalid and `InfrastructureError` when the upload is rejected or the
  /// server cannot be reached.
  Future<void> upload(LocalPhoto photo, Uint8List bytes);

  /// Uploads the file at [path] as [photo]'s content, streaming it from
  /// disk so even a long video never sits in memory whole.
  ///
  /// Same completion and error contract as [upload]; additionally throws
  /// `InfrastructureError` with code `missing_file` when the file has
  /// vanished from [path].
  Future<void> uploadFromPath(LocalPhoto photo, String path);
}
