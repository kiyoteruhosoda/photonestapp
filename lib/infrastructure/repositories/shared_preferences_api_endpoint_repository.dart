import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ApiEndpointRepository] backed by [SharedPreferences].
final class SharedPreferencesApiEndpointRepository
    implements ApiEndpointRepository {
  const SharedPreferencesApiEndpointRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _baseUrlKey = 'api.baseUrl';

  @override
  Uri? load() {
    final raw = _preferences.getString(_baseUrlKey);
    if (raw == null) return null;
    return Uri.tryParse(raw);
  }

  @override
  Future<void> save(Uri baseUrl) async {
    await _preferences.setString(_baseUrlKey, baseUrl.toString());
  }
}
