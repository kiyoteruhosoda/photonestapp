import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';

/// Returns every stored bookmark, newest first.
final class ListBookmarksUseCase {
  const ListBookmarksUseCase(this._repository);

  final BookmarkRepository _repository;

  Future<List<Bookmark>> execute() => _repository.findAll();
}
