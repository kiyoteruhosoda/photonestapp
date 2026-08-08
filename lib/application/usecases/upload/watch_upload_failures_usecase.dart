import 'package:flutterbase/domain/repositories/upload_failure_repository.dart';

/// Emits whenever the recorded upload failures change **in this isolate**.
///
/// Lets the failure list follow the running batch without polling. Writes
/// from the background upload engine happen in its own isolate, behind its
/// own store instance, so they do not arrive here — a reader picks those up
/// when the list is re-read.
final class WatchUploadFailuresUseCase {
  const WatchUploadFailuresUseCase(this._failures);

  final UploadFailureRepository _failures;

  Stream<void> execute() => _failures.changes;
}
