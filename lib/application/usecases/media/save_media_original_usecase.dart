import 'dart:typed_data';

import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_original_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Why a "save to this device" attempt did not produce a file.
enum SaveMediaFailure {
  /// The user did not grant access to the device's photo library.
  noLibraryAccess,

  /// The server could not be reached, or refused to hand over the original.
  downloadFailed,

  /// The platform refused to file the asset.
  writeFailed,
}

/// Copies one media item's original from the server into the device's photo
/// library.
///
/// Returns null on success, or the reason it did not happen — the viewer
/// turns that into a message rather than a stack trace.
final class SaveMediaOriginalUseCase {
  const SaveMediaOriginalUseCase(this._originals, this._library, this._logger);

  final MediaOriginalRepository _originals;
  final PhotoLibraryGateway _library;
  final AppLogger _logger;

  Future<SaveMediaFailure?> execute(
    MediaId id, {
    required String fileName,
    required bool isVideo,
  }) async {
    // Asked for before the download so a denied grant does not cost the
    // reader a whole original's worth of traffic first.
    if (!await _library.ensureAccess()) {
      _logger.warning('[Media] cannot save — photo library access denied');
      return SaveMediaFailure.noLibraryAccess;
    }
    // An expected failure — offline, an expired session, a purged file —
    // becomes a reason the viewer can phrase. Anything else still escapes.
    final Uint8List bytes;
    try {
      bytes = await _originals.downloadOriginal(id);
    } on AppError catch (error) {
      _logger.warning('[Media] could not download $fileName: ${error.message}');
      return SaveMediaFailure.downloadFailed;
    }
    final saved = await _library.saveToLibrary(
      fileName: fileName,
      bytes: bytes,
      isVideo: isVideo,
    );
    if (!saved) {
      _logger.warning('[Media] the platform refused to save $fileName');
      return SaveMediaFailure.writeFailed;
    }
    _logger.info('[Media] saved $fileName to the device library');
    return null;
  }
}
