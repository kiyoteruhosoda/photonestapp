/// Local persistence of the PhotoNest server address the user signed in to.
///
/// Stored separately from the session so the login screen can prefill the
/// last server even after a logout cleared the tokens.
abstract interface class ApiEndpointRepository {
  /// Base URL of the server (without the `/api` prefix), or null when the
  /// user has never signed in.
  Uri? load();

  /// Stores [baseUrl], replacing any previous one.
  Future<void> save(Uri baseUrl);
}
