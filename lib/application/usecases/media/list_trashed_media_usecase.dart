import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';

/// Reads one window of the trash, newest deletion first.
///
/// Distinct from [ListLibraryMediaUseCase]: the trash is not a filter over
/// the library but a different list, with restore as its only action and no
/// offline snapshot behind it (media that is about to be purged is exactly
/// what should not be cached).
final class ListTrashedMediaUseCase {
  const ListTrashedMediaUseCase(this._library, this._logger);

  final MediaLibraryRepository _library;
  final AppLogger _logger;

  Future<MediaLibraryPage> execute({String? cursor, int pageSize = 100}) async {
    final result = await _library.findTrashPage(
      cursor: cursor,
      pageSize: pageSize,
    );
    _logger.info(
      '[Trash] ${result.items.length} item(s), more: ${result.hasNext}',
    );
    return result;
  }
}
