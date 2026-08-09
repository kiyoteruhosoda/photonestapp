import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/upload_resumption.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';
import 'package:flutterbase/infrastructure/repositories/api_album_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_auth_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_library_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_original_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_playback_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_thumbnail_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_photo_upload_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

void main() {
  late FakeSessionRepository sessions;
  late List<http.Request> requests;

  setUp(() {
    sessions = FakeSessionRepository(testAuthSession);
    requests = [];
  });

  PhotoNestApiClient client(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return PhotoNestApiClient(
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      sessionStore: sessions,
      endpointStore: FakeApiEndpointRepository(
        Uri.parse('https://photos.example.com'),
      ),
      appLogger: RecordingAppLogger(),
    );
  }

  http.Response json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);

  group('ApiAuthRepository', () {
    LoginCredentials credentials() => LoginCredentials(
      serverUrl: Uri.parse('https://photos.example.com'),
      email: 'user@example.com',
      password: 'secret',
    );

    test('login posts email, password, and the gui:view scope', () async {
      final repository = ApiAuthRepository(
        client(
          (request) async => json({
            'access_token': 'a1',
            'refresh_token': 'r1',
            'token_type': 'Bearer',
            'scope': 'gui:view album:view',
          }),
        ),
      );

      final session = await repository.login(credentials());

      expect(jsonDecode(requests.single.body), {
        'email': 'user@example.com',
        'password': 'secret',
        'scope': ['gui:view'],
      });
      // Login itself must not carry a stale bearer token.
      expect(requests.single.headers['Authorization'], isNull);
      expect(session.accessToken, 'a1');
      expect(session.refreshToken, 'r1');
      expect(session.email, 'user@example.com');
      expect(session.scopes, ['gui:view', 'album:view']);
    });

    test(
      'login surfaces invalid credentials as AuthenticationError', //
      () async {
        final repository = ApiAuthRepository(
          client(
            (request) async => json({
              'detail': {
                'error': 'invalid_credentials',
                'message': 'Invalid e-mail or password.',
              },
            }, status: 401),
          ),
        );

        await expectLater(
          repository.login(credentials()),
          throwsA(
            isA<AuthenticationError>().having(
              (error) => error.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
      },
    );

    test(
      'logout posts to the revoke endpoint with the bearer token', //
      () async {
        final repository = ApiAuthRepository(
          client((request) async => json({'result': 'ok'})),
        );

        await repository.logout(testAuthSession);

        expect(requests.single.url.path, '/api/auth/logout');
        expect(
          requests.single.headers['Authorization'],
          'Bearer ${testAuthSession.accessToken}',
        );
      },
    );
  });

  group('ApiAlbumRepository', () {
    test('findAll maps the server payload onto Album entities', () async {
      final repository = ApiAlbumRepository(
        client(
          (request) async => json({
            'items': [
              {
                'id': 1,
                'title': 'Trip',
                'description': 'Summer',
                'coverMediaId': 12,
                'mediaCount': 34,
                'createdAt': '2026-01-01T00:00:00Z',
              },
              {'id': 2, 'title': 'Empty', 'coverMediaId': null},
            ],
            'total': 2,
            'page': 1,
            'pageSize': 200,
          }),
        ),
      );

      final albums = await repository.findAll();

      expect(requests.single.url.queryParameters, {
        'page': '1',
        'pageSize': '200',
      });
      expect(albums, hasLength(2));
      expect(albums[0].id, AlbumId(1));
      expect(albums[0].title, 'Trip');
      expect(albums[0].description, 'Summer');
      expect(albums[0].coverMediaId, MediaId(12));
      expect(albums[0].mediaCount, 34);
      expect(albums[0].createdAt, DateTime.utc(2026));
      expect(albums[1].coverMediaId, isNull);
      expect(albums[1].mediaCount, 0);
    });

    test('findAll follows the paging to the end of the list', () async {
      final repository = ApiAlbumRepository(
        client((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          // Two full pages then a short one, so the loop has to keep going
          // exactly until the server runs dry.
          final count = page < 3 ? 200 : 1;
          return json({
            'items': [
              for (var i = 0; i < count; i++)
                {'id': (page - 1) * 200 + i + 1, 'title': 'A'},
            ],
            'total': 401,
            'page': page,
            'pageSize': 200,
          });
        }),
      );

      final albums = await repository.findAll();

      expect(albums, hasLength(401));
      expect(requests, hasLength(3));
      expect(albums.last.id, AlbumId(401));
    });

    test('findAll rejects a response without items', () async {
      final repository = ApiAlbumRepository(
        client((request) async => json({'unexpected': true})),
      );
      await expectLater(
        repository.findAll(),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('findById unwraps the album envelope and its media', () async {
      final repository = ApiAlbumRepository(
        client(
          (request) async => json({
            'album': {
              'id': 3,
              'title': 'Detail',
              'mediaCount': 1,
              'coverMediaId': 5,
              'media': [
                {
                  'id': 5,
                  'filename': 'IMG.jpg',
                  'shotAt': '2026-02-03T04:05:06Z',
                  'thumbnailUrl': '/api/media/5/thumbnail?size=512',
                },
              ],
              'mediaIds': [5],
            },
          }),
        ),
      );

      final detail = await repository.findById(AlbumId(3));

      expect(requests.single.url.path, '/api/albums/3');
      expect(requests.single.url.queryParameters, {
        'page': '1',
        'pageSize': '100',
      });
      expect(detail, isNotNull);
      expect(detail!.album.title, 'Detail');
      expect(detail.media.single.id, MediaId(5));
      expect(detail.media.single.filename, 'IMG.jpg');
      expect(detail.media.single.shotAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(detail.media.single.isVideo, isFalse);
      // Without a server-side total, the total is unknown — the reader ends
      // paging on a short page instead.
      expect(detail.mediaTotal, isNull);
    });

    test('findById carries the media paging window and the total', () async {
      final repository = ApiAlbumRepository(
        client(
          (request) async => json({
            'album': {
              'id': 3,
              'title': 'Big',
              'mediaCount': 250,
              'mediaTotal': 250,
              'media': [
                {'id': 7, 'filename': 'clip.mp4', 'isVideo': true},
              ],
            },
          }),
        ),
      );

      final detail = await repository.findById(
        AlbumId(3),
        mediaPage: 3,
        mediaPageSize: 50,
      );

      expect(requests.single.url.queryParameters, {
        'page': '3',
        'pageSize': '50',
      });
      expect(detail!.mediaTotal, 250);
      expect(detail.media.single.isVideo, isTrue);
    });

    test('findById answers null for the server not_found code', () async {
      final repository = ApiAlbumRepository(
        client(
          (request) async => json({
            'detail': {'error': 'not_found', 'message': 'Album not found.'},
          }, status: 404),
        ),
      );
      expect(await repository.findById(AlbumId(9)), isNull);
    });

    test('findById rethrows other failures', () async {
      final repository = ApiAlbumRepository(
        client(
          (request) async => json({
            'detail': {'error': 'oops', 'message': 'broken'},
          }, status: 500),
        ),
      );
      await expectLater(
        repository.findById(AlbumId(9)),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('ApiMediaLibraryRepository', () {
    test('reads a page of the library newest first', () async {
      final repository = ApiMediaLibraryRepository(
        client(
          (request) async => json({
            'items': [
              {
                'id': 5,
                'filename': 'a.jpg',
                'shot_at': '2026-08-05T09:30:00Z',
                'is_video': 0,
              },
              {
                'id': 6,
                'filename': 'clip.mp4',
                'shot_at': '2026-08-04T18:00:00Z',
                'is_video': 1,
              },
            ],
            'page': 2,
            'pageSize': 50,
            'hasNext': true,
          }),
        ),
      );

      final page = await repository.findPage(page: 2, pageSize: 50);

      expect(requests.single.url.path, '/api/media');
      expect(requests.single.url.queryParameters, {
        'page': '2',
        'pageSize': '50',
        'order': 'desc',
      });
      expect(page.hasNext, isTrue);
      expect(page.items.map((item) => item.id.value), [5, 6]);
      // The endpoint answers in snake_case with 0/1 flags, unlike
      // /api/albums — a photo must not come back as a video.
      expect(page.items.first.isVideo, isFalse);
      expect(page.items.last.isVideo, isTrue);
      expect(page.items.first.shotAt, DateTime.utc(2026, 8, 5, 9, 30));
      expect(page.items.first.shotAt!.isUtc, isTrue);
    });

    test('accepts real booleans, so a stricter server still parses', () async {
      final repository = ApiMediaLibraryRepository(
        client(
          (request) async => json({
            'items': [
              {'id': 5, 'filename': 'clip.mp4', 'is_video': true},
            ],
            'hasNext': false,
          }),
        ),
      );

      final page = await repository.findPage();

      expect(page.items.single.isVideo, isTrue);
      expect(page.hasNext, isFalse);
    });

    test('media without a capture instant keeps a null shotAt', () async {
      final repository = ApiMediaLibraryRepository(
        client(
          (request) async => json({
            'items': [
              {'id': 5, 'filename': 'scan.jpg', 'shot_at': null},
            ],
            'hasNext': false,
          }),
        ),
      );

      expect((await repository.findPage()).items.single.shotAt, isNull);
    });

    test('a response without items is a failure, not an empty library', () {
      final repository = ApiMediaLibraryRepository(
        client((request) async => json({'page': 1})),
      );
      expect(repository.findPage, throwsA(isA<InfrastructureError>()));
    });
  });

  group('ApiMediaThumbnailRepository', () {
    test('fetches the thumbnail bytes at an allowed size', () async {
      final repository = ApiMediaThumbnailRepository(
        client((request) async => http.Response.bytes([7, 8], 200)),
      );

      final bytes = await repository.fetch(MediaId(5), size: 512);

      expect(requests.single.url.path, '/api/media/5/thumbnail');
      expect(requests.single.url.queryParameters, {'size': '512'});
      expect(bytes, [7, 8]);
    });

    test('rejects a size the server does not produce', () {
      final repository = ApiMediaThumbnailRepository(
        client((request) async => http.Response.bytes([], 200)),
      );
      expect(
        () => repository.fetch(MediaId(5), size: 300),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('ApiMediaPlaybackRepository', () {
    test('resolves the signed path against the signed-in server', () async {
      final repository = ApiMediaPlaybackRepository(
        client(
          (request) async => json({
            'url': '/api/dl/tok123',
            'expiresAt': '2026-08-08T12:00:00Z',
          }),
        ),
      );

      final source = await repository.sourceOf(MediaId(7));

      expect(requests.single.url.path, '/api/media/7/playback-url');
      expect(requests.single.method, 'POST');
      expect(source.url, Uri.parse('https://photos.example.com/api/dl/tok123'));
      expect(source.expiresAt, DateTime.utc(2026, 8, 8, 12));
    });

    test('a response without a URL is an error', () async {
      final repository = ApiMediaPlaybackRepository(
        client((request) async => json({'expiresAt': null})),
      );
      await expectLater(
        repository.sourceOf(MediaId(7)),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('the transcoding-in-progress code surfaces unchanged', () async {
      final repository = ApiMediaPlaybackRepository(
        client(
          (request) async => json({
            'detail': {'error': 'not_ready', 'message': 'Still processing.'},
          }, status: 409),
        ),
      );
      await expectLater(
        repository.sourceOf(MediaId(7)),
        throwsA(
          isA<InfrastructureError>().having(
            (error) => error.code,
            'code',
            'not_ready',
          ),
        ),
      );
    });
  });

  group('ApiMediaOriginalRepository', () {
    test('resolves the signed path against the signed-in server', () async {
      final repository = ApiMediaOriginalRepository(
        client(
          (request) async => json({
            'url': '/api/dl/orig123',
            'expiresAt': '2026-08-08T12:00:00Z',
          }),
        ),
      );

      final source = await repository.originalOf(MediaId(7));

      expect(requests.single.url.path, '/api/media/7/original-url');
      expect(
        source.url,
        Uri.parse('https://photos.example.com/api/dl/orig123'),
      );
      expect(source.expiresAt, DateTime.utc(2026, 8, 8, 12));
    });

    test('a response without a URL is a failure', () {
      final repository = ApiMediaOriginalRepository(
        client((request) async => json({'expiresAt': null})),
      );
      expect(
        () => repository.originalOf(MediaId(7)),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test(
      'downloading fetches the signed URL without the bearer token',
      () async {
        final repository = ApiMediaOriginalRepository(
          client((request) async {
            if (request.url.path.endsWith('/original-url')) {
              return json({'url': '/api/dl/orig123'});
            }
            return http.Response.bytes([4, 5, 6], 200);
          }),
        );

        final bytes = await repository.downloadOriginal(MediaId(7));

        expect(bytes, [4, 5, 6]);
        expect(requests.last.url.path, '/api/dl/orig123');
        // The signature is the authorisation; sending the session token to
        // whatever host the link names would only leak it.
        expect(requests.last.headers.containsKey('Authorization'), isFalse);
      },
    );
  });

  group('ApiPhotoUploadRepository', () {
    late FakeUploadResumptionRepository resumptions;

    setUp(() {
      resumptions = FakeUploadResumptionRepository();
    });

    /// The payload every chunked-upload call answers with.
    http.Response chunkState({
      String tempFileId = 'tmp-1',
      required int uploadedBytes,
      required int fileSize,
    }) {
      return json({
        'tempFileId': tempFileId,
        'fileName': 'IMG_0001.jpg',
        'fileSize': fileSize,
        'uploadedBytes': uploadedBytes,
        'status': uploadedBytes >= fileSize ? 'analyzed' : 'uploading',
        'completed': uploadedBytes >= fileSize,
      });
    }

    http.Response commitOk() => json({
      'uploaded': [
        {'tempFileId': 'tmp-1', 'status': 'success'},
      ],
    });

    ApiPhotoUploadRepository repositoryOn(
      PhotoNestApiClient apiClient, {
      int chunkSize = ApiPhotoUploadRepository.defaultChunkSize,
    }) {
      return ApiPhotoUploadRepository(
        apiClient,
        resumptions,
        RecordingAppLogger(),
        random: Random(42),
        chunkSize: chunkSize,
      );
    }

    /// Handles the whole happy path for a [fileSize]-byte file sent in
    /// [chunkSize] steps, recording the bytes each append carried.
    PhotoNestApiClient happyServer({
      required int fileSize,
      required int chunkSize,
      required List<List<int>> appended,
    }) {
      var received = 0;
      return client((request) async {
        switch (request.url.path) {
          case '/api/upload/chunks':
            return chunkState(uploadedBytes: 0, fileSize: fileSize);
          case '/api/upload/chunks/tmp-1':
            if (request.method == 'GET') {
              return chunkState(uploadedBytes: received, fileSize: fileSize);
            }
            appended.add(request.bodyBytes);
            received += request.bodyBytes.length;
            return chunkState(uploadedBytes: received, fileSize: fileSize);
          default:
            expect(request.url.path, '/api/upload/commit');
            return commitOk();
        }
      });
    }

    test('announces, appends every range in order, then commits', () async {
      final appended = <List<int>>[];
      final repository = repositoryOn(
        happyServer(fileSize: 5, chunkSize: 2, appended: appended),
        chunkSize: 2,
      );

      await repository.upload(
        testLocalPhoto(),
        Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      // announce + 3 appends + commit
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/upload/chunks',
        'PUT /api/upload/chunks/tmp-1',
        'PUT /api/upload/chunks/tmp-1',
        'PUT /api/upload/chunks/tmp-1',
        'POST /api/upload/commit',
      ]);
      expect(appended, [
        [1, 2],
        [3, 4],
        [5],
      ]);
      // Every range says where it sits in the whole file.
      expect(requests[1].headers['Content-Range'], 'bytes 0-1/5');
      expect(requests[2].headers['Content-Range'], 'bytes 2-3/5');
      expect(requests[3].headers['Content-Range'], 'bytes 4-4/5');
    });

    test('announces the file name, size and content type', () async {
      final repository = repositoryOn(
        happyServer(fileSize: 2, chunkSize: 8, appended: <List<int>>[]),
      );

      await repository.upload(
        testLocalPhoto(fileName: 'clip.mp4', isVideo: true),
        Uint8List.fromList([1, 2]),
      );

      expect(jsonDecode(requests.first.body), {
        'fileName': 'clip.mp4',
        'fileSize': 2,
        'contentType': 'video/mp4',
      });
    });

    test('every call carries the same generated upload session', () async {
      final repository = repositoryOn(
        happyServer(fileSize: 2, chunkSize: 8, appended: <List<int>>[]),
      );

      await repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2]));

      final session = requests.first.headers['X-Upload-Session'];
      expect(session, isNotNull);
      expect(session, hasLength(32));
      for (final request in requests) {
        expect(request.headers['X-Upload-Session'], session);
      }
    });

    test(
      'progress is reported against the whole file, not the chunk',
      () async {
        final repository = repositoryOn(
          happyServer(fileSize: 5, chunkSize: 2, appended: <List<int>>[]),
          chunkSize: 2,
        );
        final progress = <(int, int)>[];

        await repository.upload(
          testLocalPhoto(),
          Uint8List.fromList([1, 2, 3, 4, 5]),
          onBytes: (sent, total) => progress.add((sent, total)),
        );

        expect(progress, [(2, 5), (4, 5), (5, 5)]);
      },
    );

    test(
      'the resume point is recorded before the first byte goes out',
      () async {
        final repository = repositoryOn(
          client((request) async {
            if (request.url.path == '/api/upload/chunks') {
              return chunkState(uploadedBytes: 0, fileSize: 4);
            }
            // The append never answers — the connection died.
            throw http.ClientException('connection closed');
          }),
        );

        await expectLater(
          repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<NetworkUnreachableError>()),
        );

        final stored = resumptions.stored['asset-1'];
        expect(stored, isNotNull);
        expect(stored!.tempFileId, 'tmp-1');
        expect(stored.fileSize, 4);
        expect(
          stored.uploadSessionId,
          requests.first.headers['X-Upload-Session'],
        );
      },
    );

    test(
      'a recorded upload continues from the bytes the server holds',
      () async {
        await resumptions.save(
          UploadResumption(
            localId: 'asset-1',
            fileName: 'IMG_0001.jpg',
            fileSize: 5,
            uploadSessionId: 'session-1',
            tempFileId: 'tmp-1',
          ),
        );
        final appended = <List<int>>[];
        final repository = repositoryOn(
          client((request) async {
            if (request.method == 'GET') {
              return chunkState(uploadedBytes: 3, fileSize: 5);
            }
            if (request.url.path == '/api/upload/commit') return commitOk();
            appended.add(request.bodyBytes);
            return chunkState(uploadedBytes: 5, fileSize: 5);
          }),
        );
        final progress = <(int, int)>[];

        await repository.upload(
          testLocalPhoto(),
          Uint8List.fromList([1, 2, 3, 4, 5]),
          onBytes: (sent, total) => progress.add((sent, total)),
        );

        // No new announcement: the stored session and temp file are reused.
        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'GET /api/upload/chunks/tmp-1',
          'PUT /api/upload/chunks/tmp-1',
          'POST /api/upload/commit',
        ]);
        expect(requests.first.headers['X-Upload-Session'], 'session-1');
        // Only the tail is re-sent, and the bar starts where it left off.
        expect(appended, [
          [4, 5],
        ]);
        expect(progress, [(5, 5)]);
        // Committed, so the record is gone.
        expect(resumptions.stored, isEmpty);
      },
    );

    test('a resume point for a different file is discarded', () async {
      await resumptions.save(
        UploadResumption(
          localId: 'asset-1',
          fileName: 'IMG_0001.jpg',
          // The asset was re-encoded: same id, different size.
          fileSize: 99,
          uploadSessionId: 'session-1',
          tempFileId: 'stale',
        ),
      );
      final repository = repositoryOn(
        happyServer(fileSize: 2, chunkSize: 8, appended: <List<int>>[]),
      );

      await repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2]));

      expect(requests.first.url.path, '/api/upload/chunks');
      expect(requests.first.method, 'POST');
      expect(resumptions.cleared, contains('asset-1'));
    });

    test('an upload the server forgot is started over', () async {
      await resumptions.save(
        UploadResumption(
          localId: 'asset-1',
          fileName: 'IMG_0001.jpg',
          fileSize: 2,
          uploadSessionId: 'session-1',
          tempFileId: 'gone',
        ),
      );
      final repository = repositoryOn(
        client((request) async {
          if (request.url.path == '/api/upload/chunks/gone') {
            return json({
              'detail': {
                'error': 'upload_not_found',
                'message': 'Upload not found',
              },
            }, status: 404);
          }
          if (request.url.path == '/api/upload/chunks') {
            return chunkState(uploadedBytes: 0, fileSize: 2);
          }
          if (request.url.path == '/api/upload/commit') return commitOk();
          return chunkState(uploadedBytes: 2, fileSize: 2);
        }),
      );

      await repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2]));

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/upload/chunks/gone',
        'POST /api/upload/chunks',
        'PUT /api/upload/chunks/tmp-1',
        'POST /api/upload/commit',
      ]);
    });

    test('an append that finds the file gone re-announces it once', () async {
      var announcements = 0;
      final repository = repositoryOn(
        client((request) async {
          if (request.url.path == '/api/upload/chunks') {
            announcements++;
            return chunkState(uploadedBytes: 0, fileSize: 2);
          }
          if (request.url.path == '/api/upload/commit') return commitOk();
          if (announcements == 1) {
            // The temp file was swept up between announcing and appending.
            return json({
              'detail': {'error': 'upload_not_found', 'message': 'gone'},
            }, status: 404);
          }
          return chunkState(uploadedBytes: 2, fileSize: 2);
        }),
      );

      await repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2]));

      expect(announcements, 2);
      expect(requests.last.url.path, '/api/upload/commit');
    });

    test(
      'an offset mismatch is answered by asking where the server is',
      () async {
        final appended = <List<int>>[];
        var refused = false;
        final repository = repositoryOn(
          client((request) async {
            if (request.url.path == '/api/upload/chunks') {
              return chunkState(uploadedBytes: 0, fileSize: 4);
            }
            if (request.url.path == '/api/upload/commit') return commitOk();
            if (request.method == 'GET') {
              // Two bytes had in fact already landed.
              return chunkState(uploadedBytes: 2, fileSize: 4);
            }
            if (!refused) {
              refused = true;
              return json({
                'detail': {
                  'error': 'offset_mismatch',
                  'message':
                      'Chunk offset does not match the received size (2)',
                  'uploadedBytes': 2,
                },
              }, status: 409);
            }
            appended.add(request.bodyBytes);
            return chunkState(uploadedBytes: 4, fileSize: 4);
          }),
        );

        await repository.upload(
          testLocalPhoto(),
          Uint8List.fromList([1, 2, 3, 4]),
        );

        // The retry sends the tail the server was actually missing.
        expect(appended, [
          [3, 4],
        ]);
        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'POST /api/upload/chunks',
          'PUT /api/upload/chunks/tmp-1',
          'GET /api/upload/chunks/tmp-1',
          'PUT /api/upload/chunks/tmp-1',
          'POST /api/upload/commit',
        ]);
      },
    );

    test('a dropped connection resumes from what actually landed', () async {
      var appends = 0;
      final appended = <List<int>>[];
      final repository = repositoryOn(
        client((request) async {
          if (request.url.path == '/api/upload/chunks') {
            return chunkState(uploadedBytes: 0, fileSize: 4);
          }
          if (request.url.path == '/api/upload/commit') return commitOk();
          if (request.method == 'GET') {
            return chunkState(uploadedBytes: 1, fileSize: 4);
          }
          appends++;
          if (appends == 1) {
            // The socket died after one byte had reached the server.
            throw http.ClientException('connection reset');
          }
          appended.add(request.bodyBytes);
          return chunkState(uploadedBytes: 4, fileSize: 4);
        }),
      );

      await repository.upload(
        testLocalPhoto(),
        Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(appended, [
        [2, 3, 4],
      ]);
      expect(requests[2].method, 'GET');
      expect(requests[3].headers['Content-Range'], 'bytes 1-3/4');
    });

    test(
      'an unreachable server fails the upload but keeps the resume point',
      () async {
        final repository = repositoryOn(
          client((request) async {
            if (request.url.path == '/api/upload/chunks') {
              return chunkState(uploadedBytes: 0, fileSize: 2);
            }
            throw http.ClientException('no route to host');
          }),
        );

        await expectLater(
          repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2])),
          throwsA(isA<NetworkUnreachableError>()),
        );

        // The record survives so the next pass can carry on.
        expect(resumptions.stored['asset-1'], isNotNull);
      },
    );

    test(
      'an append that never advances gives up instead of spinning',
      () async {
        final repository = repositoryOn(
          client((request) async {
            if (request.url.path == '/api/upload/chunks') {
              return chunkState(uploadedBytes: 0, fileSize: 4);
            }
            // The server keeps answering "still nothing received".
            return chunkState(uploadedBytes: 0, fileSize: 4);
          }),
        );

        await expectLater(
          repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2, 3, 4])),
          throwsA(
            isA<InfrastructureError>().having(
              (error) => error.code,
              'code',
              'upload_stalled',
            ),
          ),
        );
      },
    );

    test('a commit rejection surfaces the server message', () async {
      final repository = repositoryOn(
        client((request) async {
          if (request.url.path == '/api/upload/chunks') {
            return chunkState(uploadedBytes: 0, fileSize: 1);
          }
          if (request.url.path == '/api/upload/commit') {
            return json({
              'uploaded': [
                {
                  'tempFileId': 'tmp-1',
                  'status': 'error',
                  'message': 'corrupt',
                },
              ],
            });
          }
          return chunkState(uploadedBytes: 1, fileSize: 1);
        }),
      );

      await expectLater(
        repository.upload(testLocalPhoto(), Uint8List.fromList([1])),
        throwsA(
          isA<InfrastructureError>().having(
            (error) => error.message,
            'message',
            'corrupt',
          ),
        ),
      );
    });

    test('an announcement without a file id is an error', () async {
      final repository = repositoryOn(
        client((request) async => json({'status': 'uploading'})),
      );

      await expectLater(
        repository.upload(testLocalPhoto(), Uint8List.fromList([1])),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('uploadFromPath streams the file range by range', () async {
      final directory = await Directory.systemTemp.createTemp('upload-test');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/clip.mp4');
      await file.writeAsBytes([1, 2, 3, 4, 5]);

      final appended = <List<int>>[];
      final repository = repositoryOn(
        happyServer(fileSize: 5, chunkSize: 2, appended: appended),
        chunkSize: 2,
      );

      await repository.uploadFromPath(
        testLocalPhoto(fileName: 'clip.mp4', isVideo: true),
        file.path,
      );

      expect(appended, [
        [1, 2],
        [3, 4],
        [5],
      ]);
      expect(jsonDecode(requests.first.body), {
        'fileName': 'clip.mp4',
        'fileSize': 5,
        'contentType': 'video/mp4',
      });
    });

    test('uploadFromPath maps a vanished file to missing_file', () async {
      final repository = repositoryOn(client((request) async => json({})));

      await expectLater(
        repository.uploadFromPath(
          testLocalPhoto(fileName: 'clip.mp4', isVideo: true),
          '/nowhere/does-not-exist.mp4',
        ),
        throwsA(
          isA<InfrastructureError>().having(
            (error) => error.code,
            'code',
            'missing_file',
          ),
        ),
      );
      expect(requests, isEmpty);
    });

    test('an empty file is refused before anything is announced', () async {
      final repository = repositoryOn(client((request) async => json({})));

      await expectLater(
        repository.upload(testLocalPhoto(), Uint8List(0)),
        throwsA(
          isA<InfrastructureError>().having(
            (error) => error.code,
            'code',
            'upload_failed',
          ),
        ),
      );
      expect(requests, isEmpty);
    });

    test(
      'an unsupported extension is refused before any network call', //
      () async {
        final repository = repositoryOn(client((request) async => json({})));

        await expectLater(
          repository.upload(
            testLocalPhoto(fileName: 'notes.txt'),
            Uint8List.fromList([1]),
          ),
          throwsA(
            isA<InfrastructureError>().having(
              (error) => error.code,
              'code',
              'unsupported_format',
            ),
          ),
        );
        expect(requests, isEmpty);
      },
    );
  });
}
