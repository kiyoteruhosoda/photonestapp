/// The signed-in person's own account, as the server holds it.
///
/// Distinct from `AuthSession`, which carries tokens and the identity the
/// app signed in *with*. This is what the server says the account is *now* —
/// an e-mail changed elsewhere shows up here without a new sign-in.
///
/// Read-only on purpose. The app changes an account's *credentials*
/// (password, authenticator) but not the fields that name it; the reasons
/// are in `docs/adr/0014-account-screen-covers-credentials-only.md`.
final class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.email,
    required this.twoFactorEnabled,
  });

  final int id;

  /// The address the account signs in with.
  final String email;

  /// Whether a TOTP authenticator is registered for this account.
  final bool twoFactorEnabled;

  /// The same account with [twoFactorEnabled] flipped, after an
  /// enable/disable the server confirmed.
  AccountProfile withTwoFactor({required bool enabled}) =>
      AccountProfile(id: id, email: email, twoFactorEnabled: enabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountProfile &&
          other.id == id &&
          other.email == email &&
          other.twoFactorEnabled == twoFactorEnabled);

  @override
  int get hashCode => Object.hash(id, email, twoFactorEnabled);

  /// Deliberately e-mail-free: an account in a log line is personal data.
  @override
  String toString() => 'AccountProfile($id, 2fa: $twoFactorEnabled)';
}

/// What the reader needs on screen to register an authenticator app.
///
/// Held only until the code is confirmed. The secret is never stored on the
/// device: if the reader backs out mid-way, nothing was enabled and the next
/// attempt starts from a fresh secret.
final class TwoFactorEnrollment {
  const TwoFactorEnrollment({
    required this.secret,
    required this.otpauthUri,
    this.qrImage,
  });

  /// The shared secret, in the base32 form an authenticator takes when it is
  /// typed in by hand.
  final String secret;

  /// `otpauth://` URI. On a phone this is the short path — the authenticator
  /// app registers the account when the URI is opened, with nothing typed.
  final Uri otpauthUri;

  /// A QR image of [otpauthUri] as a `data:` URI, when the server sent one.
  ///
  /// For registering from a *second* device; the phone showing the QR cannot
  /// scan its own screen.
  final Uri? qrImage;

  /// Deliberately secret-free: an enrollment in a log line is a credential.
  @override
  String toString() => 'TwoFactorEnrollment(hasQr: ${qrImage != null})';
}
