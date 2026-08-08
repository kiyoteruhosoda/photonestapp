import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/domain/repositories/media_original_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// A signed URL for one media item's untouched original.
///
/// The viewer opens on the 2048px rendition and only asks for this when the
/// reader taps "show the original" — an original can be tens of megabytes,
/// so fetching one per swipe would be an expensive default.
final class GetMediaOriginalUseCase {
  const GetMediaOriginalUseCase(this._originals);

  final MediaOriginalRepository _originals;

  Future<SignedMediaUrl> execute(MediaId id) => _originals.originalOf(id);
}
