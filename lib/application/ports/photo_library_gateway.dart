import 'dart:typed_data';

import 'package:flutterbase/domain/entities/local_photo.dart';

/// Application port to the device's photo library.
///
/// Behind it sits a platform plugin (Infrastructure); use cases and tests
/// only ever see this contract. Videos are out of scope — implementations
/// report photos only.
abstract interface class PhotoLibraryGateway {
  /// Asks the platform for permission to read the photo library.
  ///
  /// Returns true when at least partial access was granted. Safe to call
  /// repeatedly — the platform only prompts when it has to.
  Future<bool> ensureAccess();

  /// Photos taken strictly after [since], newest first, at most [limit].
  ///
  /// Pass null to list the most recent photos regardless of age.
  Future<List<LocalPhoto>> photosTakenAfter(DateTime? since, {int limit = 100});

  /// The photo's original encoded bytes, or null when the asset has
  /// disappeared from the library.
  Future<Uint8List?> readOriginalBytes(String localId);

  /// A small preview of the photo, or null when the asset has disappeared.
  Future<Uint8List?> readThumbnail(String localId, {required int size});

  /// Emits whenever the platform reports a change in the photo library.
  ///
  /// The events carry no payload on purpose: the sync use case re-queries
  /// the library itself, so a missed event costs nothing.
  Stream<void> get libraryChanges;
}
