import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/entities/upload_resumption.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/photo_upload_repository.dart';
import 'package:photonest/domain/repositories/upload_resumption_repository.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [PhotoUploadRepository] backed by the server's resumable chunked upload:
/// `POST /api/upload/chunks` announces the file and hands back a
/// `tempFileId`, `PUT /api/upload/chunks/{id}` appends one byte range at a
/// time (`Content-Range`), and `POST /api/upload/commit` hands the finished
/// file to the import queue.
///
/// Sending in ranges rather than as one multipart body is what makes a
/// backup survive a dropped connection: the server counts what it received,
/// so an interrupted video continues from there instead of starting over —
/// which on a phone, mid-video, on hotel Wi-Fi, used to mean never
/// finishing at all. The resume point is remembered in
/// [UploadResumptionRepository] so it also survives the process being
/// killed, which is the usual end of a background pass.
///
/// Every call carries the same `X-Upload-Session` header. The server can
/// also track the session via a cookie, but a generated header survives
/// however the platform handles cookies, so the client always sends its own.
final class ApiPhotoUploadRepository implements PhotoUploadRepository {
  ApiPhotoUploadRepository(
    this._client,
    this._resumptions,
    this._logger, {
    Random? random,
    int chunkSize = defaultChunkSize,
  }) : _random = random ?? Random.secure(),
       _chunkSize = chunkSize,
       assert(chunkSize > 0, 'chunkSize must be positive');

  final PhotoNestApiClient _client;
  final UploadResumptionRepository _resumptions;
  final AppLogger _logger;
  final Random _random;
  final int _chunkSize;

  /// Bytes per append.
  ///
  /// Big enough that a photo goes in one request and the per-request
  /// overhead stays irrelevant for a video; small enough that a dropped
  /// connection costs a few seconds of re-sending rather than minutes.
  static const int defaultChunkSize = 4 * 1024 * 1024;

  /// How many times one chunk may be re-tried after asking the server where
  /// it actually got to. Beyond this the upload fails and the recorded
  /// resume point carries it into the next pass.
  static const int _maxResyncAttempts = 3;

  static const String _sessionHeader = 'X-Upload-Session';

  /// Image types the server accepts, keyed by lower-case file extension.
  ///
  /// The server rejects any upload whose content type does not start with
  /// `image/` or `video/`, so the octet-stream default is not an option.
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
    return _uploadWith(photo, _MemoryContent(bytes), onBytes: onBytes);
  }

  @override
  Future<void> uploadFromPath(
    LocalPhoto photo,
    String path, {
    UploadBytesProgress? onBytes,
  }) async {
    final file = File(path);
    final int length;
    try {
      length = await file.length();
    } on FileSystemException catch (error) {
      throw InfrastructureError(
        'The file for ${photo.fileName} is gone from $path.',
        code: 'missing_file',
        cause: error,
      );
    }
    // Ranges are read from disk as the socket drains them, so even a
    // multi-gigabyte video costs a buffer rather than its size in memory.
    await _uploadWith(photo, _FileContent(file, length), onBytes: onBytes);
  }

  Future<void> _uploadWith(
    LocalPhoto photo,
    _UploadContent content, {
    UploadBytesProgress? onBytes,
  }) async {
    // Checked before anything is announced: the server declares the same
    // rule, and failing here keeps a hopeless file out of its temp storage.
    final contentType = _contentTypeFor(photo.fileName);
    if (content.length <= 0) {
      throw InfrastructureError(
        '${photo.fileName} has no content to upload.',
        code: 'upload_failed',
      );
    }

    var state = await _startOrResume(photo, content, contentType);
    try {
      state = await _sendRemaining(photo, content, state, onBytes);
    } on _UploadForgotten {
      // The server no longer holds the part-received file — its temp storage
      // was cleaned up while the phone was away. Announce the file again and
      // send it from the beginning, once.
      _logger.info(
        '[Upload] the server forgot ${photo.fileName} — starting over',
      );
      await _forgetResumePoint(photo, state.tempFileId);
      state = await _begin(photo, content, contentType);
      state = await _sendRemaining(photo, content, state, onBytes);
    }

    await _commit(photo, state);
    // The temp file is now the server's problem; a stale resume point would
    // only send the next attempt to a file id that no longer exists.
    await _forgetResumePoint(photo, state.tempFileId);
  }

  /// Picks up where a previous attempt left off, or announces a new upload.
  Future<_ChunkedUpload> _startOrResume(
    LocalPhoto photo,
    _UploadContent content,
    MediaType contentType,
  ) async {
    final stored = await _findResumePoint(photo);
    if (stored == null) return _begin(photo, content, contentType);

    if (!stored.describes(fileName: photo.fileName, fileSize: content.length)) {
      // The asset changed under us (re-encoded, or the id was reused).
      // Appending to the old upload would splice two different files.
      _logger.info(
        '[Upload] ${photo.fileName} no longer matches its resume point '
        '— starting over',
      );
      await _forgetResumePoint(photo, stored.tempFileId);
      return _begin(photo, content, contentType);
    }

    try {
      final state = await _fetchState(
        stored.uploadSessionId,
        stored.tempFileId,
      );
      _logger.info(
        '[Upload] resuming ${photo.fileName} at '
        '${state.uploadedBytes}/${content.length} bytes',
      );
      return state;
    } on InfrastructureError catch (error) {
      if (error.code != 'upload_not_found') rethrow;
      await _forgetResumePoint(photo, stored.tempFileId);
      return _begin(photo, content, contentType);
    }
  }

  /// Announces the file and records the resume point the server hands back.
  Future<_ChunkedUpload> _begin(
    LocalPhoto photo,
    _UploadContent content,
    MediaType contentType,
  ) async {
    final sessionId = _newSessionId();
    final payload = await _client.postJson(
      '/upload/chunks',
      {
        'fileName': photo.fileName,
        'fileSize': content.length,
        'contentType': contentType.toString(),
      },
      headers: {_sessionHeader: sessionId},
    );
    final state = _stateFrom(sessionId, payload);
    // Recorded before the first byte goes out: an upload interrupted during
    // its very first chunk is exactly the one worth resuming. A store that
    // cannot be written costs the resume, not the upload — so it is logged
    // and the send goes ahead.
    try {
      await _resumptions.save(
        UploadResumption(
          localId: photo.localId,
          fileName: photo.fileName,
          fileSize: content.length,
          uploadSessionId: sessionId,
          tempFileId: state.tempFileId,
        ),
      );
    } on AppError catch (error) {
      _logger.warning(
        '[Upload] could not record the resume point for ${photo.fileName}: '
        '${error.message}',
      );
    }
    return state;
  }

  /// Appends chunks until the server says it has the whole file.
  Future<_ChunkedUpload> _sendRemaining(
    LocalPhoto photo,
    _UploadContent content,
    _ChunkedUpload from,
    UploadBytesProgress? onBytes,
  ) async {
    var state = from;
    var attempts = 0;
    while (!state.completed) {
      final start = state.uploadedBytes;
      final end = min(start + _chunkSize, content.length);
      try {
        final sent = await _appendChunk(content, state, start, end, onBytes);
        if (sent.uploadedBytes > start || sent.completed) {
          state = sent;
          attempts = 0;
          continue;
        }
        // The server accepted the request but is no further along. Retrying
        // the same range forever would spin, so this counts as a failure.
        attempts = _countAttempt(
          photo,
          attempts,
          'the append made no progress',
        );
        state = await _fetchState(state.sessionId, state.tempFileId);
      } on NetworkUnreachableError catch (error) {
        // The connection dropped part-way through the range. How much landed
        // is the server's to say — and if it cannot be reached at all, this
        // throws again and the upload ends with its resume point recorded.
        attempts = _countAttempt(photo, attempts, error.message);
        state = await _fetchState(state.sessionId, state.tempFileId);
      } on InfrastructureError catch (error) {
        if (error.code == 'upload_not_found') throw const _UploadForgotten();
        if (error.code != 'offset_mismatch' && error.code != 'upload_busy') {
          rethrow;
        }
        // Either another request wrote in between, or our idea of the resume
        // point was stale. Both are answered by asking where the server is.
        attempts = _countAttempt(photo, attempts, error.message);
        state = await _fetchState(state.sessionId, state.tempFileId);
      }
    }
    return state;
  }

  /// Appends `[start, end)` and returns the server's new resume point.
  Future<_ChunkedUpload> _appendChunk(
    _UploadContent content,
    _ChunkedUpload state,
    int start,
    int end,
    UploadBytesProgress? onBytes,
  ) async {
    final payload = await _client.putStream(
      '/upload/chunks/${state.tempFileId}',
      openBody: () => content.openRange(start, end),
      contentLength: end - start,
      headers: {
        _sessionHeader: state.sessionId,
        // The server validates this against the declared size and refuses a
        // body whose length disagrees, so a truncated send cannot be
        // mistaken for progress.
        'Content-Range': 'bytes $start-${end - 1}/${content.length}',
      },
      // Reported against the whole file rather than the chunk: the caller is
      // drawing one bar per photo, and a resumed upload should start where
      // it left off instead of at zero.
      onBytes: onBytes == null
          ? null
          : (sent, _) => onBytes(start + sent, content.length),
    );
    return _stateFrom(state.sessionId, payload);
  }

  /// Asks the server how much of the upload it holds.
  Future<_ChunkedUpload> _fetchState(
    String sessionId,
    String tempFileId,
  ) async {
    final payload = await _client.getJson(
      '/upload/chunks/$tempFileId',
      headers: {_sessionHeader: sessionId},
    );
    return _stateFrom(sessionId, payload);
  }

  /// Hands the received file to the import queue.
  Future<void> _commit(LocalPhoto photo, _ChunkedUpload state) async {
    final committed = await _client.postJson(
      '/upload/commit',
      {
        'files': [
          {'tempFileId': state.tempFileId},
        ],
      },
      headers: {_sessionHeader: state.sessionId},
    );
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

  /// The recorded resume point, or null when there is none — including when
  /// the store could not be read.
  ///
  /// A store that cannot answer means the resume is unavailable, not that
  /// the photo cannot be backed up: the upload starts from the beginning,
  /// which is exactly what it did before there was a resume point at all.
  Future<UploadResumption?> _findResumePoint(LocalPhoto photo) async {
    try {
      return await _resumptions.find(photo.localId);
    } on AppError catch (error) {
      _logger.warning(
        '[Upload] could not read the resume point for ${photo.fileName}: '
        '${error.message}',
      );
      return null;
    }
  }

  /// Forgets the resume point for [tempFileId], best-effort.
  ///
  /// Never allowed to fail the upload. After a successful commit the server
  /// already holds the photo: throwing here would have the caller record it
  /// as failed and never mark it uploaded, so the next pass would send the
  /// same photo again. A row left behind is harmless by comparison — the
  /// next attempt finds the temp file gone and starts over.
  Future<void> _forgetResumePoint(LocalPhoto photo, String tempFileId) async {
    try {
      await _resumptions.clear(photo.localId, tempFileId: tempFileId);
    } on AppError catch (error) {
      _logger.warning(
        '[Upload] could not clear the resume point for ${photo.fileName}: '
        '${error.message}',
      );
    }
  }

  /// Records one failed attempt at the current chunk, or gives up.
  int _countAttempt(LocalPhoto photo, int attempts, String reason) {
    final next = attempts + 1;
    if (next > _maxResyncAttempts) {
      throw InfrastructureError(
        'Gave up sending ${photo.fileName} after $_maxResyncAttempts '
        'attempts: $reason',
        code: 'upload_stalled',
      );
    }
    _logger.warning(
      '[Upload] retrying ${photo.fileName} '
      '(attempt $next/$_maxResyncAttempts): $reason',
    );
    return next;
  }

  /// Reads the upload state the server reports on every chunked-upload call.
  static _ChunkedUpload _stateFrom(
    String sessionId,
    Map<String, dynamic> payload,
  ) {
    final tempFileId = payload['tempFileId'] as String?;
    if (tempFileId == null) {
      throw const InfrastructureError('Chunked upload returned no file id.');
    }
    return _ChunkedUpload(
      sessionId: sessionId,
      tempFileId: tempFileId,
      uploadedBytes: (payload['uploadedBytes'] as num?)?.toInt() ?? 0,
      completed: payload['completed'] == true,
    );
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

/// The server's view of one chunked upload.
final class _ChunkedUpload {
  const _ChunkedUpload({
    required this.sessionId,
    required this.tempFileId,
    required this.uploadedBytes,
    required this.completed,
  });

  final String sessionId;
  final String tempFileId;

  /// Bytes the server holds — the offset the next chunk must start at.
  final int uploadedBytes;

  /// True once the whole file has arrived and may be committed.
  final bool completed;
}

/// The bytes of one upload, readable range by range.
///
/// An interface rather than two code paths because resuming means reading
/// from an offset, which a file and an in-memory buffer answer differently
/// but the upload loop should not have to know about.
abstract interface class _UploadContent {
  /// Total size in bytes.
  int get length;

  /// The bytes in `[start, end)`.
  Stream<List<int>> openRange(int start, int end);
}

/// Content the platform handed over as bytes (no readable file on disk).
final class _MemoryContent implements _UploadContent {
  const _MemoryContent(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Stream<List<int>> openRange(int start, int end) =>
      // A view, not a copy: the range is already in memory.
      Stream<List<int>>.value(Uint8List.sublistView(_bytes, start, end));
}

/// Content still on disk, read range by range as it is sent.
final class _FileContent implements _UploadContent {
  const _FileContent(this._file, this.length);

  final File _file;

  @override
  final int length;

  @override
  Stream<List<int>> openRange(int start, int end) => _file.openRead(start, end);
}

/// Internal signal that the server no longer knows the temp file.
final class _UploadForgotten implements Exception {
  const _UploadForgotten();
}
