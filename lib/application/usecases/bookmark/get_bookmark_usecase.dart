import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

/// Looks up a single bookmark.
///
/// This is the use case a deep link lands on: `https://<host>/bookmarks/42`
/// resolves to [BookmarkId] 42, which may or may not still exist on this
/// device. Null means "not here", and the caller renders a not-found state.
final class GetBookmarkUseCase {
  const GetBookmarkUseCase(this._repository);

  final BookmarkRepository _repository;

  Future<Bookmark?> execute(BookmarkId id) => _repository.findById(id);
}
