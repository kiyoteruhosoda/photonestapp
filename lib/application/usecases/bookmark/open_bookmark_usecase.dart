import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';

/// Hands a bookmark's URL to the platform.
///
/// The composition of a Domain entity with an outbound port is the point:
/// Presentation asks for "open this bookmark" and never learns that
/// `url_launcher` exists.
final class OpenBookmarkUseCase {
  const OpenBookmarkUseCase(this._launcher, this._logger);

  final ExternalLinkLauncher _launcher;
  final AppLogger _logger;

  /// Returns false when the device has nothing that can open the URL.
  Future<bool> execute(Bookmark bookmark) async {
    final opened = await _launcher.open(bookmark.url);
    if (opened) {
      _logger.info('[Bookmarks] opened #${bookmark.id.value} externally');
    } else {
      _logger.warning(
        '[Bookmarks] no handler for ${bookmark.url} '
        '(#${bookmark.id.value})',
      );
    }
    return opened;
  }
}
