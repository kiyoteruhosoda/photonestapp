import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';

/// Reads one page of the whole media library, newest capture first.
///
/// The timeline screen calls this once per page as it scrolls, carrying the
/// previous page's cursor. There is no offline snapshot behind it (unlike the
/// album list): the library is unbounded and grows constantly, so a stale
/// local copy would be misleading rather than useful. Cached *thumbnails*
/// still render offline once a page has been read.
final class ListLibraryMediaUseCase {
  const ListLibraryMediaUseCase(this._library, this._logger);

  final MediaLibraryRepository _library;
  final AppLogger _logger;

  /// Reads the window after [cursor], or the newest window when it is null.
  ///
  /// [query] narrows the library; the default reads everything.
  Future<MediaLibraryPage> execute({
    String? cursor,
    int pageSize = 100,
    MediaLibraryQuery query = const MediaLibraryQuery(),
  }) async {
    final result = await _library.findPage(
      cursor: cursor,
      pageSize: pageSize,
      query: query,
    );
    _logger.info(
      '[Library] ${cursor == null ? 'first page' : 'page after cursor'} — '
      '${result.items.length} item(s), more: ${result.hasNext}'
      '${query.isUnfiltered ? '' : ', filtered by $query'}',
    );
    return result;
  }
}
