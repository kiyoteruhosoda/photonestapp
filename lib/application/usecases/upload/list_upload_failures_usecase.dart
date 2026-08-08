import 'package:flutterbase/domain/entities/upload_failure.dart';
import 'package:flutterbase/domain/repositories/upload_failure_repository.dart';

/// The photos that are currently failing to upload, most recent first.
final class ListUploadFailuresUseCase {
  const ListUploadFailuresUseCase(this._failures);

  final UploadFailureRepository _failures;

  Future<List<UploadFailure>> execute() => _failures.list();
}
