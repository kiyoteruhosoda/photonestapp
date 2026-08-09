import 'package:photonest/domain/errors/app_error.dart';

/// A photo or video that exists in the device's photo library.
///
/// [localId] is the platform's stable asset identifier — it is what the
/// upload history remembers, so the same photo is never uploaded twice.
/// Identity is the [localId]; file name, timestamp, and kind are
/// descriptive.
final class LocalPhoto {
  /// Throws [DomainError] when [localId] is blank — without an id the photo
  /// can be neither read back nor remembered as uploaded.
  factory LocalPhoto({
    required String localId,
    required String fileName,
    required DateTime takenAt,
    bool isVideo = false,
  }) {
    if (localId.trim().isEmpty) {
      throw const DomainError('LocalPhoto id must not be blank.');
    }
    return LocalPhoto._(
      localId: localId,
      fileName: fileName,
      takenAt: takenAt.toUtc(),
      isVideo: isVideo,
    );
  }

  const LocalPhoto._({
    required this.localId,
    required this.fileName,
    required this.takenAt,
    required this.isVideo,
  });

  /// Platform asset identifier, stable across app restarts.
  final String localId;

  /// File name the photo will carry when uploaded.
  final String fileName;

  /// Capture instant, always in UTC.
  final DateTime takenAt;

  /// True when the asset is a video rather than a still photo.
  final bool isVideo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPhoto && other.localId == localId);

  @override
  int get hashCode => localId.hashCode;

  @override
  String toString() => 'LocalPhoto($localId, $fileName)';
}
