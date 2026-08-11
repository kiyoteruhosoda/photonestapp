import 'package:photonest/domain/errors/app_error.dart';

/// Schemes a PhotoNest server URL may use.
const Set<String> allowedServerSchemes = {'http', 'https'};

/// What the user submits on the login screen, validated and normalised.
///
/// The factory is the only way to build one, so a use case never sees an
/// empty password or a server address that is not a web URL. The password is
/// deliberately excluded from [toString] so it can never leak into a log.
final class LoginCredentials {
  /// Throws [DomainError] when the server URL is not an absolute
  /// `http`/`https` address, the e-mail is not shaped like an address, or
  /// the password is empty.
  factory LoginCredentials({
    required Uri serverUrl,
    required String email,
    required String password,
    String? totpCode,
  }) {
    if (!serverUrl.hasScheme ||
        !allowedServerSchemes.contains(serverUrl.scheme)) {
      throw DomainError('Server URL must be http or https, got "$serverUrl".');
    }
    if (serverUrl.host.isEmpty) {
      throw DomainError('Server URL must have a host, got "$serverUrl".');
    }
    final normalisedEmail = email.trim();
    // Full RFC 5322 validation belongs to the server; this only rejects
    // input that cannot possibly be an address, so the round trip is spared.
    final atIndex = normalisedEmail.indexOf('@');
    if (atIndex <= 0 || atIndex == normalisedEmail.length - 1) {
      throw const DomainError(
        'E-mail address must contain a local part and host.',
      );
    }
    if (password.isEmpty) {
      throw const DomainError('Password must not be empty.');
    }
    // Authenticator apps display the code in groups ("123 456") and a paste
    // carries the spacing along; the server compares digits. A code that is
    // nothing but spacing is the same as not having one.
    final digits = (totpCode ?? '').replaceAll(RegExp(r'\s'), '');
    return LoginCredentials._(
      serverUrl: serverUrl,
      email: normalisedEmail,
      password: password,
      totpCode: digits.isEmpty ? null : digits,
    );
  }

  const LoginCredentials._({
    required this.serverUrl,
    required this.email,
    required this.password,
    required this.totpCode,
  });

  /// Base address of the PhotoNest server, without the `/api` prefix.
  final Uri serverUrl;

  /// Trimmed account e-mail address.
  final String email;

  /// The password as typed. Never logged, never persisted.
  final String password;

  /// The authenticator's current code, or null when the reader has not been
  /// asked for one.
  ///
  /// Null on the first attempt: the app cannot know whether an account has
  /// an authenticator until the server says `totp_required`, and asking
  /// everyone for a code up front would put an unanswerable field in front
  /// of every reader who has none.
  final String? totpCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoginCredentials &&
          other.serverUrl == serverUrl &&
          other.email == email &&
          other.password == password &&
          other.totpCode == totpCode);

  @override
  int get hashCode => Object.hash(serverUrl, email, password, totpCode);

  @override
  String toString() => 'LoginCredentials($email @ $serverUrl)';
}
