import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/media_library_page.dart';
import 'package:flutterbase/domain/repositories/media_library_repository.dart';

/// Reads one page of the whole media library, newest capture first.
///
/// The timeline screen calls this once per page as it scrolls. There is no
/// offline snapshot behind it (unlike the album list): the library is
/// unbounded and grows constantly, so a stale local copy would be misleading
/// rather than useful. Cached *thumbnails* still render offline once a page
/// has been read.
final class ListLibraryMediaUseCase {
  const ListLibraryMediaUseCase(this._library, this._logger);

  final MediaLibraryRepository _library;
  final AppLogger _logger;

  Future<MediaLibraryPage> execute({int page = 1, int pageSize = 100}) async {
    final result = await _library.findPage(page: page, pageSize: pageSize);
    _logger.info(
      '[Library] page $page — ${result.items.length} item(s), '
      'more: ${result.hasNext}',
    );
    return result;
  }
}
