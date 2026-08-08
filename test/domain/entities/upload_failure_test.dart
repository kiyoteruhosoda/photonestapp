import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/upload_failure.dart';

import '../../support/fakes.dart';

void main() {
  UploadFailure failure({
    String localId = 'a',
    String fileName = 'a.jpg',
    UploadFailureReason reason = UploadFailureReason.rejected,
    int attempts = 1,
    bool automatic = false,
  }) {
    return UploadFailure(
      photo: testLocalPhoto(localId: localId, fileName: fileName),
      reason: reason,
      message: 'the server said no',
      failedAt: DateTime.utc(2026, 8, 8, 10),
      attempts: attempts,
      automatic: automatic,
    );
  }

  test('carries every field it was constructed with', () {
    final subject = failure(
      reason: UploadFailureReason.unsupportedFormat,
      attempts: 4,
      automatic: true,
    );

    expect(subject.photo.localId, 'a');
    expect(subject.reason, UploadFailureReason.unsupportedFormat);
    expect(subject.message, 'the server said no');
    expect(subject.failedAt, DateTime.utc(2026, 8, 8, 10));
    expect(subject.attempts, 4);
    expect(subject.automatic, isTrue);
  });

  test('a first attempt from a manual run is the default', () {
    final subject = UploadFailure(
      photo: testLocalPhoto(),
      reason: UploadFailureReason.rejected,
      message: 'no',
      failedAt: DateTime.utc(2026),
    );

    expect(subject.attempts, 1);
    expect(subject.automatic, isFalse);
  });

  test('identity is the photo — a new attempt is the same problem', () {
    // The record is the photo's *current* problem, not a log line, so a
    // second attempt replaces the first rather than joining it.
    expect(failure(attempts: 1), failure(attempts: 5));
    expect(failure(attempts: 1).hashCode, failure(attempts: 5).hashCode);
  });

  test('two different photos are different failures', () {
    expect(failure(localId: 'a'), isNot(failure(localId: 'b')));
  });

  test('toString names the photo, the reason and the attempts', () {
    final text = failure(
      reason: UploadFailureReason.unreachable,
      attempts: 3,
    ).toString();

    expect(text, contains('a'));
    expect(text, contains('unreachable'));
    expect(text, contains('3'));
  });
}
