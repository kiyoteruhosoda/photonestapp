/// Base class for all typed application errors.
sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;
}

/// An error originating from a domain rule violation.
final class DomainError extends AppError {
  const DomainError(super.message);
}

/// An error from the infrastructure layer (I/O, network, DB).
final class InfrastructureError extends AppError {
  const InfrastructureError(super.message, {this.cause, this.code});
  final Object? cause;

  /// Stable, language-neutral error code from the failing system (for
  /// example a server's `not_found`), when one was provided.
  final String? code;
}

/// The server rejected the caller's identity — wrong credentials, or an
/// expired session that could not be refreshed.
///
/// Separated from [InfrastructureError] because Presentation reacts
/// differently: an authentication failure sends the user to the login
/// screen, while an infrastructure failure offers a retry.
final class AuthenticationError extends AppError {
  const AuthenticationError(super.message, {this.code});

  /// Stable, language-neutral error code from the server (for example
  /// `invalid_credentials` or `invalid_token`), when one was provided.
  final String? code;
}

/// An unexpected / unclassified runtime error.
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message, {this.cause, this.stackTrace});
  final Object? cause;
  final StackTrace? stackTrace;
}
