import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/upload_resumption.dart';
import 'package:flutterbase/domain/errors/app_error.dart';

void main() {
  UploadResumption resumption({
    String localId = 'asset-1',
    String fileName = 'IMG_0001.jpg',
    int fileSize = 1024,
    String uploadSessionId = 'session-1',
    String tempFileId = 'tmp-1',
  }) {
    return UploadResumption(
      localId: localId,
      fileName: fileName,
      fileSize: fileSize,
      uploadSessionId: uploadSessionId,
      tempFileId: tempFileId,
    );
  }

  test('carries everything the resume needs to address the server', () {
    final record = resumption();

    expect(record.localId, 'asset-1');
    expect(record.fileName, 'IMG_0001.jpg');
    expect(record.fileSize, 1024);
    expect(record.uploadSessionId, 'session-1');
    expect(record.tempFileId, 'tmp-1');
  });

  test('rejects a blank photo id', () {
    expect(() => resumption(localId: '  '), throwsA(isA<DomainError>()));
  });

  test('rejects a record that cannot address the temp file', () {
    expect(() => resumption(uploadSessionId: ''), throwsA(isA<DomainError>()));
    expect(() => resumption(tempFileId: '  '), throwsA(isA<DomainError>()));
  });

  test('rejects a non-positive size', () {
    expect(() => resumption(fileSize: 0), throwsA(isA<DomainError>()));
    expect(() => resumption(fileSize: -1), throwsA(isA<DomainError>()));
  });

  test('describes the same file only when name and size both match', () {
    final record = resumption();

    expect(record.describes(fileName: 'IMG_0001.jpg', fileSize: 1024), isTrue);
    // Re-encoded: the server is holding bytes of something else now.
    expect(record.describes(fileName: 'IMG_0001.jpg', fileSize: 2048), isFalse);
    expect(record.describes(fileName: 'other.jpg', fileSize: 1024), isFalse);
  });

  test('identity is the photo — one upload in flight per asset', () {
    expect(resumption(tempFileId: 'tmp-1'), resumption(tempFileId: 'tmp-2'));
    expect(
      resumption(tempFileId: 'tmp-1').hashCode,
      resumption(tempFileId: 'tmp-2').hashCode,
    );
    expect(resumption(), isNot(resumption(localId: 'asset-2')));
  });

  test('toString names the photo, the temp file and the size', () {
    expect(
      resumption().toString(),
      'UploadResumption(asset-1, tmp-1, 1024 bytes)',
    );
  });
}
