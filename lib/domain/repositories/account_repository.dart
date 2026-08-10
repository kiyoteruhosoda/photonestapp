import 'package:photonest/domain/entities/account_profile.dart';

/// Boundary to the signed-in person's own account on the server.
///
/// Separate from `AuthRepository`, which opens and closes sessions. These
/// calls change the account itself, and every one of them needs a session
/// that already exists.
abstract interface class AccountRepository {
  /// The account as the server holds it, including whether an authenticator
  /// is registered.
  Future<AccountProfile> load();

  /// Sets a new password.
  ///
  /// Returns nothing. The endpoint answers with the account, but a password
  /// change alters no field the screen draws — and echoing it back would put
  /// a credential response where a profile response is expected.
  Future<void> changePassword(String newPassword);

  /// Starts registering an authenticator and returns what to show the
  /// reader. **Nothing is enabled** until [confirmTwoFactor] succeeds.
  Future<TwoFactorEnrollment> beginTwoFactorEnrollment();

  /// Finishes registration by proving the reader's app produces [code] from
  /// [secret]. Throws when the code does not match.
  Future<void> confirmTwoFactor({required String secret, required String code});

  /// Removes the registered authenticator.
  Future<void> disableTwoFactor();
}
