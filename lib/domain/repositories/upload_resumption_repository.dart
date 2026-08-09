import 'package:flutterbase/domain/entities/upload_resumption.dart';

/// Remembers the in-flight chunked uploads of the signed-in account, so an
/// upload interrupted by a lost connection — or by the OS killing the app
/// mid-backup — continues from the bytes the server already holds.
///
/// Scoped per destination like the upload history: a temp file belongs to
/// one server, and offering it to another would address nothing.
abstract interface class UploadResumptionRepository {
  /// The record for [localId], or null when there is no upload to resume.
  Future<UploadResumption?> find(String localId);

  /// Stores [resumption], replacing any earlier record for the same photo.
  Future<void> save(UploadResumption resumption);

  /// Forgets the record for [localId] — the upload finished, or the server
  /// no longer knows the temp file.
  Future<void> clear(String localId);
}
