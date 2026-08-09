import 'package:photonest/domain/entities/local_photo.dart';

/// Remembers which device photos have already been uploaded **to the
/// signed-in account**.
///
/// This is what makes automatic upload idempotent: the library watcher may
/// report the same photo any number of times, but a photo whose id is in the
/// history is never sent again. The history is per destination — a photo
/// sent to one server/account still counts as pending after signing into
/// another.
abstract interface class UploadHistoryRepository {
  /// Ids of every photo uploaded from this device to the active account.
  /// Empty while signed out.
  Future<Set<String>> uploadedLocalIds();

  /// Records that [photo] was uploaded at [uploadedAt] (UTC).
  Future<void> markUploaded(LocalPhoto photo, DateTime uploadedAt);
}
