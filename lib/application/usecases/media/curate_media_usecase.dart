import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/repositories/media_curation_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Marks favourites and moves media in and out of the trash.
///
/// One use case rather than three: they are the same decision from the
/// reader's side ("change how this item is filed") and share the logging that
/// makes a destructive action traceable afterwards.
final class CurateMediaUseCase {
  const CurateMediaUseCase(this._curation, this._logger);

  final MediaCurationRepository _curation;
  final AppLogger _logger;

  /// Returns the state the server settled on, which is not always what was
  /// asked for — another device may have changed it in between.
  Future<bool> setFavorite(MediaId id, {required bool favorite}) async {
    final settled = await _curation.setFavorite(id, favorite: favorite);
    _logger.info('[Media] ${id.value} favorite: $settled');
    return settled;
  }

  Future<void> moveToTrash(MediaId id) async {
    await _curation.moveToTrash(id);
    _logger.info('[Media] ${id.value} moved to trash');
  }

  Future<void> restore(MediaId id) async {
    await _curation.restore(id);
    _logger.info('[Media] ${id.value} restored from trash');
  }
}
