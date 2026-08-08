import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';
import 'package:flutterbase/infrastructure/repositories/api_album_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_auth_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_library_repository.dart';
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

  group('ApiPhotoUploadRepository', () {
    test('prepares then commits under one upload session', () async {
      final apiClient = client((request) async {
        if (request.url.path == '/api/upload/prepare') {
          return json({
            'tempFileId': 'tmp-1',
            'fileName': 'IMG_0001.jpg',
            'fileSize': 3,
            'status': 'analyzed',
          });
        }
        expect(request.url.path, '/api/upload/commit');
        expect(jsonDecode(request.body), {
          'files': [
            {'tempFileId': 'tmp-1'},
          ],
        });
        return json({
          'uploaded': [
            {'tempFileId': 'tmp-1', 'status': 'success'},
          ],
        });
      });
      final repository = ApiPhotoUploadRepository(
        apiClient,
        random: Random(42),
      );

      await repository.upload(testLocalPhoto(), Uint8List.fromList([1, 2, 3]));

      expect(requests, hasLength(2));
      final prepare = requests[0];
      final commit = requests[1];
      expect(
        prepare.headers['Content-Type'],
        startsWith('multipart/form-data'),
      );
      // The same generated session id must accompany both calls.
      final sessionId = prepare.headers['X-Upload-Session'];
      expect(sessionId, isNotNull);
      expect(sessionId, hasLength(32));
      expect(commit.headers['X-Upload-Session'], sessionId);
      // The multipart body carries the file part with an image content type.
      final body = utf8.decode(prepare.bodyBytes, allowMalformed: true);
      expect(body, contains('name="file"'));
      expect(body, contains('filename="IMG_0001.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
    });

    test('a commit rejection surfaces the server message', () async {
      final apiClient = client((request) async {
        if (request.url.path == '/api/upload/prepare') {
          return json({'tempFileId': 'tmp-1'});
        }
        return json({
          'uploaded': [
            {'tempFileId': 'tmp-1', 'status': 'error', 'message': 'corrupt'},
          ],
        });
      });
      final repository = ApiPhotoUploadRepository(apiClient);

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

    test('a prepare response without a file id is an error', () async {
      final repository = ApiPhotoUploadRepository(
        client((request) async => json({'status': 'analyzed'})),
      );
      await expectLater(
        repository.upload(testLocalPhoto(), Uint8List.fromList([1])),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('a video upload carries a video content type', () async {
      final repository = ApiPhotoUploadRepository(
        client((request) async {
          if (request.url.path.endsWith('/upload/prepare')) {
            return json({'tempFileId': 't1'});
          }
          return json({
            'uploaded': [
              {'status': 'success'},
            ],
          });
        }),
        random: Random(1),
      );

      await repository.upload(
        testLocalPhoto(fileName: 'clip.mp4', isVideo: true),
        Uint8List.fromList([1, 2]),
      );

      final prepare = requests.first;
      expect(prepare.body, contains('content-type: video/mp4'));
    });

    test('uploadFromPath streams the file with its content type', () async {
      final directory = await Directory.systemTemp.createTemp('upload-test');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/clip.mp4');
      await file.writeAsBytes([1, 2, 3, 4]);

      final repository = ApiPhotoUploadRepository(
        client((request) async {
          if (request.url.path.endsWith('/upload/prepare')) {
            return json({'tempFileId': 't1'});
          }
          return json({
            'uploaded': [
              {'status': 'success'},
            ],
          });
        }),
        random: Random(1),
      );

      await repository.uploadFromPath(
        testLocalPhoto(fileName: 'clip.mp4', isVideo: true),
        file.path,
      );

      final prepare = requests.first;
      expect(prepare.body, contains('content-type: video/mp4'));
      expect(prepare.bodyBytes, containsAllInOrder([1, 2, 3, 4]));
    });

    test('uploadFromPath maps a vanished file to missing_file', () async {
      final repository = ApiPhotoUploadRepository(
        client((request) async => json({'tempFileId': 't1'})),
      );

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

    test(
      'an unsupported extension is refused before any network call', //
      () async {
        final repository = ApiPhotoUploadRepository(
          client((request) async => json({})),
        );
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
