import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';

/// One device photo offered on the upload screen.
final class UploadCandidate {
  const UploadCandidate({required this.photo, required this.alreadyUploaded});

  final LocalPhoto photo;

  /// True when the upload history says this photo was already sent, so the
  /// screen can show it as done instead of selectable.
  final bool alreadyUploaded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadCandidate &&
          other.photo == photo &&
          other.alreadyUploaded == alreadyUploaded);

  @override
  int get hashCode => Object.hash(photo, alreadyUploaded);

  @override
  String toString() =>
      'UploadCandidate(${photo.localId}, uploaded: $alreadyUploaded)';
}

/// What the upload screen renders: either "no access" or the recent photos
/// with their upload state.
final class UploadCandidates {
  const UploadCandidates({required this.accessGranted, required this.photos});

  const UploadCandidates.denied()
    : accessGranted = false,
      photos = const <UploadCandidate>[];

  /// False when the user has not granted photo-library access — the screen
  /// shows an explanation instead of an empty grid.
  final bool accessGranted;

  final List<UploadCandidate> photos;
}

/// Lists recent device photos for the upload screen.
final class ListUploadCandidatesUseCase {
  const ListUploadCandidatesUseCase(this._library, this._history);

  final PhotoLibraryGateway _library;
  final UploadHistoryRepository _history;

  Future<UploadCandidates> execute({int limit = 100}) async {
    final granted = await _library.ensureAccess();
    if (!granted) return const UploadCandidates.denied();

    final photos = await _library.photosTakenAfter(null, limit: limit);
    final uploaded = await _history.uploadedLocalIds();
    return UploadCandidates(
      accessGranted: true,
      photos: photos
          .map(
            (photo) => UploadCandidate(
              photo: photo,
              alreadyUploaded: uploaded.contains(photo.localId),
            ),
          )
          .toList(),
    );
  }
}
