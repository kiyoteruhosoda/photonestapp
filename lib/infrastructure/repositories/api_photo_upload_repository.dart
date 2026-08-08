import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/photo_upload_repository.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// [PhotoUploadRepository] backed by the server's two-phase upload:
/// `POST /api/upload/prepare` (multipart) then `POST /api/upload/commit`.
///
/// Both calls carry the same `X-Upload-Session` header. The server can also
/// track the session via a cookie, but a generated header survives however
/// the platform handles cookies, so the client always sends its own.
final class ApiPhotoUploadRepository implements PhotoUploadRepository {
  ApiPhotoUploadRepository(this._client, {Random? random})
    : _random = random ?? Random.secure();

  final PhotoNestApiClient _client;
  final Random _random;

  static const String _sessionHeader = 'X-Upload-Session';

  /// Image types the server accepts, keyed by lower-case file extension.
  ///
  /// The prepare endpoint rejects any part whose Content-Type does not start
  /// with `image/` or `video/`, so the octet-stream default is not an option.
  static const Map<String, String> _imageSubtypeByExtension = {
    'jpg': 'jpeg',
    'jpeg': 'jpeg',
    'png': 'png',
    'gif': 'gif',
    'bmp': 'bmp',
    'tif': 'tiff',
    'tiff': 'tiff',
    'webp': 'webp',
    'heic': 'heic',
    'heif': 'heif',
  };

  /// Video types the server accepts, keyed by lower-case file extension.
  static const Map<String, String> _videoSubtypeByExtension = {
    'mp4': 'mp4',
    'm4v': 'x-m4v',
    'mov': 'quicktime',
    'avi': 'x-msvideo',
    'mkv': 'x-matroska',
    'webm': 'webm',
    '3gp': '3gpp',
    'mts': 'mp2t',
    'm2ts': 'mp2t',
  };

  @override
  Future<void> upload(
    LocalPhoto photo,
    Uint8List bytes, {
    UploadBytesProgress? onBytes,
  }) {
    return _uploadWith(
      photo,
      () async => http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: photo.fileName,
        contentType: _contentTypeFor(photo.fileName),
      ),
      onBytes: onBytes,
    );
  }

  @override
  Future<void> uploadFromPath(
    LocalPhoto photo,
    String path, {
    UploadBytesProgress? onBytes,
  }) {
    // `fromPath` streams from disk chunk by chunk, so a multi-gigabyte
    // video costs a buffer, not its whole size, in memory.
    return _uploadWith(photo, () async {
      try {
        return await http.MultipartFile.fromPath(
          'file',
          path,
          filename: photo.fileName,
          contentType: _contentTypeFor(photo.fileName),
        );
      } on FileSystemException catch (error) {
        throw InfrastructureError(
          'The file for ${photo.fileName} is gone from $path.',
          code: 'missing_file',
          cause: error,
        );
      }
    }, onBytes: onBytes);
  }

  Future<void> _uploadWith(
    LocalPhoto photo,
    Future<http.MultipartFile> Function() buildFile, {
    UploadBytesProgress? onBytes,
  }) async {
    final session = _newSessionId();
    final headers = {_sessionHeader: session};

    final prepared = await _client.postMultipart(
      '/upload/prepare',
      headers: headers,
      buildFile: buildFile,
      onBytes: onBytes,
    );
    final tempFileId = prepared['tempFileId'] as String?;
    if (tempFileId == null) {
      throw const InfrastructureError('Upload prepare returned no file id.');
    }

    final committed = await _client.postJson('/upload/commit', {
      'files': [
        {'tempFileId': tempFileId},
      ],
    }, headers: headers);
    final uploaded = committed['uploaded'];
    final outcome = uploaded is List && uploaded.isNotEmpty
        ? uploaded.first
        : null;
    if (outcome is! Map<String, dynamic> || outcome['status'] != 'success') {
      final message = outcome is Map<String, dynamic>
          ? outcome['message'] as String?
          : null;
      throw InfrastructureError(
        message ?? 'The server did not accept ${photo.fileName}.',
      );
    }
  }

  static MediaType _contentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final imageSubtype = _imageSubtypeByExtension[extension];
    if (imageSubtype != null) return MediaType('image', imageSubtype);
    final videoSubtype = _videoSubtypeByExtension[extension];
    if (videoSubtype != null) return MediaType('video', videoSubtype);
    throw InfrastructureError(
      'Unsupported media type ".$extension" for $fileName.',
      code: 'unsupported_format',
    );
  }

  /// 32 hex characters, matching the shape the server generates itself.
  String _newSessionId() {
    const hex = '0123456789abcdef';
    return List.generate(32, (_) => hex[_random.nextInt(16)]).join();
  }
}
