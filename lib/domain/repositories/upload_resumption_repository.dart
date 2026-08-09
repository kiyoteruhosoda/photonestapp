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

  /// Forgets the record for [localId], but only while it still names
  /// [tempFileId] — the upload finished, or the server no longer knows that
  /// temp file.
  ///
  /// Scoped to the temp file because two uploads of the same photo can
  /// overlap (a manual upload started during an automatic pass). Each
  /// announces its own temp file and the later one takes the row; an
  /// unconditional delete would let whichever finished first throw away the
  /// other's resume point, costing it everything it had sent.
  Future<void> clear(String localId, {required String tempFileId});
}
