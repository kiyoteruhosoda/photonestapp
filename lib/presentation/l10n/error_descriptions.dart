import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';

/// Maps a typed load error onto a localised, user-facing message.
///
/// The same design the login screen uses with `LoginFailure`: the domain's
/// error messages are developer-facing English, so screens translate the
/// *kind* of failure instead of showing the message verbatim. Screens showing
/// an [Object] from an `AsyncError` route it through here.
String describeLoadError(Object error, AppLocalizations l10n) {
  return switch (error) {
    AuthenticationError() => l10n.commonErrorSessionExpired,
    InfrastructureError() => l10n.commonErrorNetwork,
    _ => l10n.commonError,
  };
}
