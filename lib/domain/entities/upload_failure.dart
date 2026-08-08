import 'package:flutterbase/domain/entities/local_photo.dart';

/// Why a device photo could not be uploaded, as something the UI can
/// translate.
///
/// Mirrors the reasons the upload use case produces; kept in the domain so
/// the persisted record survives without depending on the Application layer.
enum UploadFailureReason {
  /// The asset vanished from the device library between listing and upload.
  missingFromLibrary,

  /// The file type is one the server does not accept.
  unsupportedFormat,

  /// The session expired and could not be refreshed.
  sessionExpired,

  /// The server could not be reached — retrying once connected may succeed.
  unreachable,

  /// The server answered and refused the photo.
  rejected,
}

/// One device photo that is currently failing to upload.
///
/// Two failures are the same when they name the same photo: the record is
/// the photo's *current* problem, not a log line, so a new attempt updates
/// it and a success removes it.
final class UploadFailure {
  const UploadFailure({
    required this.photo,
    required this.reason,
    required this.message,
    required this.failedAt,
    this.attempts = 1,
    this.automatic = false,
  });

  final LocalPhoto photo;
  final UploadFailureReason reason;

  /// Developer-facing detail for the logs; never shown to the user verbatim.
  final String message;

  /// Instant (UTC) of the most recent attempt.
  final DateTime failedAt;

  /// How many attempts in a row have failed. A count that keeps climbing is
  /// what tells a reader this photo will not fix itself.
  final int attempts;

  /// True when the most recent attempt came from a background pass rather
  /// than a manual upload.
  final bool automatic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadFailure && other.photo.localId == photo.localId);

  @override
  int get hashCode => photo.localId.hashCode;

  @override
  String toString() =>
      'UploadFailure(${photo.localId}: ${reason.name}, $attempts attempt(s))';
}
