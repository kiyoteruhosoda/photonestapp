import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';

/// Boundary to the library's tags and to which media carries which of them.
///
/// Separate from `MediaCurationRepository` for the same reason curation is
/// separate from listing: filing a photo under a label is its own operation,
/// with its own permission on the server, and a screen that only browses
/// should not be able to reach it.
abstract interface class MediaTagRepository {
  /// Tags in the library whose name contains [query], newest matching the
  /// server's order, at most [limit] of them.
  ///
  /// A blank [query] asks for the first [limit] tags rather than none — that
  /// is what an editor shows before the reader has typed anything.
  Future<List<Tag>> findAll({String query = '', int limit = 20});

  /// The tags currently on [id].
  ///
  /// Read from the server rather than carried on the listed media: the
  /// listing endpoint does not report tags, and an editor that guessed from
  /// stale state would drop tags another device added.
  Future<List<Tag>> findByMedia(MediaId id);

  /// Replaces the whole tag set on [id] with [tagIds] and returns the set
  /// the server settled on.
  ///
  /// A replacement rather than add/remove calls because that is what the
  /// endpoint offers, and because it is what makes the result unambiguous:
  /// the answer is the media's tags, not a diff to reconcile.
  Future<List<Tag>> replaceMediaTags(MediaId id, List<TagId> tagIds);
}
