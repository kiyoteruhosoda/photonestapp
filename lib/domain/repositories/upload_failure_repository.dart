import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/entities/upload_failure.dart';

/// Persistence of the photos that are currently failing to upload.
///
/// Scoped to the signed-in account by the implementation, like the upload
/// history: the same photo can be fine for one server and rejected by
/// another.
abstract interface class UploadFailureRepository {
  /// Every live failure, most recent attempt first.
  Future<List<UploadFailure>> list();

  /// Records one failed attempt, incrementing [UploadFailure.attempts] when
  /// this photo was already failing.
  Future<void> record({
    required LocalPhoto photo,
    required UploadFailureReason reason,
    required String message,
    required bool automatic,
    required DateTime failedAt,
  });

  /// Forgets [localId]'s failure — called when the photo finally uploads.
  Future<void> clear(String localId);

  /// Forgets every failure. The list screen's "dismiss all".
  Future<void> clearAll();

  /// Emits whenever the stored failures change, so a screen can follow them
  /// without polling.
  Stream<void> get changes;
}
