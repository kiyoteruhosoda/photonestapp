import 'package:photonest/domain/repositories/upload_failure_repository.dart';

/// Forgets the recorded upload failures.
///
/// The records are a standing to-do list rather than a log, so a reader who
/// has seen them can clear them; a photo that keeps failing simply comes
/// back on the next attempt.
final class DismissUploadFailuresUseCase {
  const DismissUploadFailuresUseCase(this._failures);

  final UploadFailureRepository _failures;

  Future<void> execute() => _failures.clearAll();
}
