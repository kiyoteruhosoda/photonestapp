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
}
