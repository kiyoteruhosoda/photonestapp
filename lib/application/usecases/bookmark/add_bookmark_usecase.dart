import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';

/// Stores a new bookmark.
///
/// [BookmarkDraft] has already rejected blank titles and non-web URLs by the
/// time it gets here, so this use case only has to persist and record.
final class AddBookmarkUseCase {
  const AddBookmarkUseCase(this._repository, this._logger);

  final BookmarkRepository _repository;
  final AppLogger _logger;

  Future<Bookmark> execute(BookmarkDraft draft) async {
    final stored = await _repository.add(draft);
    _logger.info('[Bookmarks] added #${stored.id.value} — ${stored.title}');
    return stored;
  }
}
