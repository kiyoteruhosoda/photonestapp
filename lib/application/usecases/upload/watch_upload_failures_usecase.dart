import 'package:flutterbase/domain/repositories/upload_failure_repository.dart';

/// Emits whenever the recorded upload failures change.
///
/// Lets the failure list follow writes made by the running batch — and by
/// the background pass, while the app happens to be open — instead of
/// polling.
final class WatchUploadFailuresUseCase {
  const WatchUploadFailuresUseCase(this._failures);

  final UploadFailureRepository _failures;

  Stream<void> execute() => _failures.changes;
}
