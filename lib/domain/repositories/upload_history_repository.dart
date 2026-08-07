import 'package:flutterbase/domain/entities/local_photo.dart';

/// Remembers which device photos have already been uploaded.
///
/// This is what makes automatic upload idempotent: the library watcher may
/// report the same photo any number of times, but a photo whose id is in the
/// history is never sent again.
abstract interface class UploadHistoryRepository {
  /// Ids of every photo that has been uploaded from this device.
  Future<Set<String>> uploadedLocalIds();

  /// Records that [photo] was uploaded at [uploadedAt] (UTC).
  Future<void> markUploaded(LocalPhoto photo, DateTime uploadedAt);
}
