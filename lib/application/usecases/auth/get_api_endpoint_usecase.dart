import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';

/// The last PhotoNest server address the user signed in to, for prefilling
/// the login form.
final class GetApiEndpointUseCase {
  const GetApiEndpointUseCase(this._endpoints);

  final ApiEndpointRepository _endpoints;

  Uri? execute() => _endpoints.load();
}
