import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

/// Stores the bookmarks the user has saved.
///
/// Implementations live in `infrastructure/repositories/`; the interface says
/// nothing about SQLite so the storage technology can be swapped without the
/// Application layer noticing.
abstract interface class BookmarkRepository {
  /// All bookmarks, newest first.
  Future<List<Bookmark>> findAll();

  /// The bookmark with [id], or null when nothing is stored under it.
  ///
  /// Returning null rather than throwing keeps "the deep link points at a
  /// bookmark that was deleted" an ordinary outcome instead of a failure.
  Future<Bookmark?> findById(BookmarkId id);

  /// Stores [draft] and returns it with the assigned id and creation time.
  Future<Bookmark> add(BookmarkDraft draft);

  /// Deletes the bookmark with [id]. Deleting a missing id is a no-op.
  Future<void> remove(BookmarkId id);
}
