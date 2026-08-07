import 'dart:typed_data';

import 'package:flutterbase/application/ports/photo_library_gateway.dart';

/// Reads a preview of a device photo for the upload screen's grid.
final class GetLocalThumbnailUseCase {
  const GetLocalThumbnailUseCase(this._library);

  final PhotoLibraryGateway _library;

  Future<Uint8List?> execute(String localId, {int size = 256}) =>
      _library.readThumbnail(localId, size: size);
}
