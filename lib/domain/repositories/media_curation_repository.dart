import 'package:photonest/domain/value_objects/media_id.dart';

/// Boundary to the operations that change a media item rather than read it:
/// marking a favourite, moving to the trash, restoring from it.
///
/// Separate from `MediaLibraryRepository` (which lists) so that a screen that
/// only browses cannot reach the destructive calls, and so the listing
/// boundary keeps its single job.
abstract interface class MediaCurationRepository {
  /// Sets whether [id] is a favourite. Returns the state the server settled
  /// on — the request can lose a race with another device.
  Future<bool> setFavorite(MediaId id, {required bool favorite});

  /// Moves [id] to the trash. Reversible with [restore] until the server
  /// purges the file.
  Future<void> moveToTrash(MediaId id);

  /// Brings [id] back out of the trash.
  ///
  /// Throws when the file has already been purged — the row still exists but
  /// there is nothing left to restore, and the caller must say so rather
  /// than appear to succeed.
  Future<void> restore(MediaId id);
}
