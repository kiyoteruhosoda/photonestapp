import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';

/// Deletes a stored bookmark.
final class RemoveBookmarkUseCase {
  const RemoveBookmarkUseCase(this._repository, this._logger);

  final BookmarkRepository _repository;
  final AppLogger _logger;

  Future<void> execute(BookmarkId id) async {
    await _repository.remove(id);
    _logger.info('[Bookmarks] removed #${id.value}');
  }
}
