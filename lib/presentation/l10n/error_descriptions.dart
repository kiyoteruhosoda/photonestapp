import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/application/usecases/upload/upload_photos_usecase.dart';
import 'package:photonest/domain/entities/upload_failure.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';

/// Maps a typed load error onto a localised, user-facing message.
///
/// The same design the login screen uses with `LoginFailure`: the domain's
/// error messages are developer-facing English, so screens translate the
/// *kind* of failure instead of showing the message verbatim. Screens showing
/// an [Object] from an `AsyncError` route it through here.
///
/// Only a transport failure earns the "check your connection" wording — an
/// error the server *did* respond with (an HTTP 500, a malformed payload)
/// is not something reconnecting will fix, so it stays generic.
String describeLoadError(Object error, AppLocalizations l10n) {
  return switch (error) {
    NetworkUnreachableError() => l10n.commonErrorNetwork,
    AuthenticationError() => l10n.commonErrorSessionExpired,
    _ => l10n.commonError,
  };
}

/// Maps a single photo's upload failure onto a localised message for the
/// failure list.
String describeUploadFailure(
  PhotoUploadFailureReason reason,
  AppLocalizations l10n,
) {
  return switch (reason) {
    PhotoUploadFailureReason.missingFromLibrary => l10n.uploadFailureMissing,
    PhotoUploadFailureReason.unsupportedFormat => l10n.uploadFailureUnsupported,
    PhotoUploadFailureReason.sessionExpired => l10n.commonErrorSessionExpired,
    PhotoUploadFailureReason.unreachable => l10n.commonErrorNetwork,
    PhotoUploadFailureReason.rejected => l10n.uploadFailureRejected,
  };
}

/// Maps a persisted upload failure's reason onto a localised message.
///
/// A separate mapping from [describeUploadFailure] because the persisted
/// record has its own domain enum: the batch's in-memory reasons belong to
/// the Application layer and must not become the storage format.
String describeRecordedFailure(
  UploadFailureReason reason,
  AppLocalizations l10n,
) {
  return switch (reason) {
    UploadFailureReason.missingFromLibrary => l10n.uploadFailureMissing,
    UploadFailureReason.unsupportedFormat => l10n.uploadFailureUnsupported,
    UploadFailureReason.sessionExpired => l10n.commonErrorSessionExpired,
    UploadFailureReason.unreachable => l10n.commonErrorNetwork,
    UploadFailureReason.rejected => l10n.uploadFailureRejected,
  };
}

/// Maps a failed "save to this device" onto a localised message.
String describeSaveFailure(SaveMediaFailure failure, AppLocalizations l10n) {
  return switch (failure) {
    SaveMediaFailure.noLibraryAccess => l10n.mediaSaveNoAccess,
    SaveMediaFailure.downloadFailed => l10n.mediaSaveDownloadFailed,
    SaveMediaFailure.writeFailed => l10n.mediaSaveWriteFailed,
  };
}

/// Maps a playback-source error onto a localised message for the player
/// overlay.
///
/// `not_ready` gets its own wording: the server is still transcoding, so
/// "try again later" is truthful where "broken" would not be.
String describePlaybackError(Object error, AppLocalizations l10n) {
  return switch (error) {
    NetworkUnreachableError() => l10n.commonErrorNetwork,
    AuthenticationError() => l10n.commonErrorSessionExpired,
    InfrastructureError(code: 'not_ready') => l10n.videoNotReady,
    _ => l10n.videoUnavailable,
  };
}
