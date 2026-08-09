import 'dart:typed_data';

import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_thumbnail_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaThumbnailRepository] backed by `/api/media/{id}/thumbnail`.
final class ApiMediaThumbnailRepository implements MediaThumbnailRepository {
  const ApiMediaThumbnailRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<Uint8List> fetch(MediaId id, {required int size}) {
    if (!allowedThumbnailSizes.contains(size)) {
      throw InfrastructureError(
        'Thumbnail size $size is not one of $allowedThumbnailSizes.',
      );
    }
    return _client.getBytes(
      '/media/${id.value}/thumbnail',
      query: {'size': '$size'},
    );
  }
}
