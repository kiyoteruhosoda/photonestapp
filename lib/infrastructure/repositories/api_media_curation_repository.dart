import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_curation_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaCurationRepository] backed by the favourite / delete / restore
/// endpoints.
///
/// Like the listing endpoint, these answer in snake_case with 0/1 flags.
final class ApiMediaCurationRepository implements MediaCurationRepository {
  const ApiMediaCurationRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<bool> setFavorite(MediaId id, {required bool favorite}) async {
    final payload = await _client.postJson('/media/${id.value}/favorite', {
      'favorite': favorite,
    });
    final settled = payload['is_favorite'];
    // The server's answer wins over what was asked for: another device may
    // have changed it in between, and the screen should show what is stored.
    if (settled == null) {
      throw const InfrastructureError('Favorite response carried no state.');
    }
    return settled == true || settled == 1;
  }

  @override
  Future<void> moveToTrash(MediaId id) => _client.delete('/media/${id.value}');

  @override
  Future<void> restore(MediaId id) async {
    await _client.postJson('/media/${id.value}/restore', const {});
  }
}
