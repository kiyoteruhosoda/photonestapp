import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Boundary to changing albums: making them, renaming them, and filing
/// media under them.
///
/// Separate from `AlbumRepository` for the same reason tagging is separate
/// from listing: the server guards these calls with their own permissions
/// (`album:create`, `album:edit`), and a screen that only browses albums
/// should not be able to reach them. Reading stays on `AlbumRepository`,
/// which is also where the offline snapshot hangs — nothing here is served
/// from a snapshot, because a change the server never accepted is not a
/// change.
abstract interface class AlbumEditingRepository {
  /// Creates an album named [title] holding [mediaIds], and returns the
  /// album the server stored.
  ///
  /// The server's answer wins over what was asked for: it trims the name
  /// and picks the cover, and the caller should show what exists rather
  /// than what was sent.
  Future<Album> create({
    required String title,
    String? description,
    List<MediaId> mediaIds = const <MediaId>[],
  });

  /// Renames [id] to [title] and replaces its description, returning the
  /// album the server settled on.
  ///
  /// Only these two fields are sent. The endpoint updates what it is given
  /// and leaves the rest alone, so a rename cannot disturb the album's
  /// media or who it is shared with — neither of which this app offers to
  /// change.
  Future<Album> updateDetails(
    AlbumId id, {
    required String title,
    String? description,
  });

  /// Every media id [id] currently holds, in the album's display order.
  ///
  /// Exists because the server takes a *replacement* set rather than an
  /// "add this one" call: putting one photo into an album means sending
  /// the ids it already had plus the new one, so they have to be read
  /// first.
  Future<List<MediaId>> mediaIdsOf(AlbumId id);

  /// Replaces everything [id] holds with [mediaIds] and returns the album
  /// the server settled on.
  ///
  /// A replacement rather than an append because that is what the endpoint
  /// offers. Callers that mean "add" read [mediaIdsOf] first — see
  /// `EditAlbumUseCase.addMedia`, which is the only intended caller.
  Future<Album> replaceMedia(AlbumId id, List<MediaId> mediaIds);
}
