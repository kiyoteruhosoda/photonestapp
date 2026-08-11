import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/account_repository.dart';

/// Reads the signed-in account and changes the two things that keep the
/// reader able to get back into it: the password and the authenticator.
///
/// One use case rather than several: the account screen needs all of them
/// together, and they share the logging that makes a credential change
/// traceable.
final class ManageAccountUseCase {
  const ManageAccountUseCase(this._accounts, this._logger);

  /// Shortest password the server accepts. Checked here so a too-short entry
  /// is refused before it travels, and so the screen can say the rule up
  /// front rather than after a round trip.
  ///
  /// **The server is still the authority** — it applies the same minimum,
  /// and this is a copy for the reader's benefit, not a replacement.
  static const int minimumPasswordLength = 8;

  final AccountRepository _accounts;
  final AppLogger _logger;

  /// The account as the server holds it.
  Future<AccountProfile> load() => _accounts.load();

  /// Sets a new password.
  ///
  /// Whitespace is **not** trimmed: sign-in does not trim either, so a
  /// password stripped here could not be typed back in.
  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < minimumPasswordLength) {
      throw const DomainError('Password is too short.');
    }
    await _accounts.changePassword(newPassword);
    // No identifier, no length, nothing about the value: a credential change
    // is worth recording, its content never is.
    _logger.info('[Account] password changed');
  }

  /// Starts registering an authenticator. Nothing changes on the server
  /// until [confirmTwoFactor].
  Future<TwoFactorEnrollment> beginTwoFactorEnrollment() =>
      _accounts.beginTwoFactorEnrollment();

  /// Finishes registration with the code the reader's app produced.
  ///
  /// The code is trimmed because authenticator apps display it in groups
  /// ("123 456") and a paste carries the spaces along; the server compares
  /// digits.
  Future<void> confirmTwoFactor({
    required String secret,
    required String code,
  }) async {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) {
      throw const DomainError('Enter the code from your authenticator app.');
    }
    await _accounts.confirmTwoFactor(secret: secret, code: digits);
    _logger.info('[Account] two-factor enabled');
  }

  /// Removes the registered authenticator.
  Future<void> disableTwoFactor() async {
    await _accounts.disableTwoFactor();
    _logger.info('[Account] two-factor disabled');
  }
}
