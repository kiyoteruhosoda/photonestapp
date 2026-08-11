import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/account_repository.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [AccountRepository] backed by the server's `/api/auth` endpoints.
///
/// The account's own fields come from `/auth/me`; the password goes through
/// `/auth/profile`; the authenticator has its own three calls under
/// `/auth/2fa`.
final class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<AccountProfile> load() async {
    // Two requests because the server splits them, and both are needed
    // before the screen can draw anything — a half-loaded account would
    // show a two-factor switch whose position is a guess.
    final profile = await _client.getJson('/auth/me');
    final twoFactor = await _client.getJson('/auth/2fa/status');

    final id = profile['id'];
    final email = profile['email'];
    if (id is! int || email is! String) {
      throw const InfrastructureError('Account response was not an account.');
    }
    return AccountProfile(
      id: id,
      email: email,
      // Absent means "the server did not say", and saying "off" for that
      // would invite the reader to turn on what may already be on.
      twoFactorEnabled: _requireBool(twoFactor['enabled'], 'Two-factor status'),
    );
  }

  @override
  Future<void> changePassword(String newPassword) async {
    // Only the password: the endpoint updates the fields it is given, and
    // echoing the e-mail back would let a stale copy overwrite an address
    // changed elsewhere.
    await _client.putJson('/auth/profile', {'password': newPassword});
  }

  @override
  Future<TwoFactorEnrollment> beginTwoFactorEnrollment() async {
    final payload = await _client.postJson('/auth/2fa/setup', const {});
    final secret = payload['secret'];
    final uri = Uri.tryParse(payload['otpauth_uri'] as String? ?? '');
    if (secret is! String || secret.isEmpty || uri == null) {
      throw const InfrastructureError(
        'Two-factor setup response carried no secret.',
      );
    }
    return TwoFactorEnrollment(
      secret: secret,
      otpauthUri: uri,
      // Optional: the QR is for registering from a second device, and the
      // secret alone is enough to finish on this one.
      qrImage: Uri.tryParse(payload['qr_data_uri'] as String? ?? ''),
    );
  }

  @override
  Future<void> confirmTwoFactor({
    required String secret,
    required String code,
  }) async {
    final payload = await _client.postJson('/auth/2fa/confirm', {
      'secret': secret,
      'code': code,
    });
    // The server answers 400 for a wrong code, which the client has already
    // turned into a failure. Reading the flag guards the other direction: a
    // 200 that did not actually enable anything must not look like success.
    if (!_requireBool(payload['enabled'], 'Two-factor confirmation')) {
      throw const InfrastructureError('Two-factor was not enabled.');
    }
  }

  /// Removes the registered authenticator.
  ///
  /// The response body is not read. Unlike the confirmation — where a 200
  /// could still mean "the code did not match" if the server ever changed —
  /// there is no half-success here: the endpoint clears the secret and then
  /// answers, so the status code is the whole answer.
  @override
  Future<void> disableTwoFactor() => _client.delete('/auth/2fa');

  static bool _requireBool(Object? raw, String subject) {
    if (raw is! bool) {
      throw InfrastructureError('$subject was not reported.');
    }
    return raw;
  }
}
