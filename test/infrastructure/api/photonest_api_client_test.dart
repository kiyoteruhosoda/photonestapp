import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

void main() {
  late FakeSessionRepository sessions;
  late FakeApiEndpointRepository endpoints;
  late RecordingAppLogger logger;
  late List<http.Request> requests;

  setUp(() {
    sessions = FakeSessionRepository(testAuthSession);
    endpoints = FakeApiEndpointRepository(
      Uri.parse('https://photos.example.com'),
    );
    logger = RecordingAppLogger();
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
      endpointStore: endpoints,
      appLogger: logger,
    );
  }

  http.Response json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);

  group('URL resolution', () {
    test('prefixes /api under the stored endpoint', () async {
      final subject = client((request) async => json({'ok': true}));
      await subject.getJson('/albums', query: {'page': '1'});

      final uri = requests.single.url;
      expect(uri.toString(), 'https://photos.example.com/api/albums?page=1');
    });

    test('keeps a base path when the server lives under one', () async {
      endpoints = FakeApiEndpointRepository(
        Uri.parse('https://example.com/photonest/'),
      );
      final subject = client((request) async => json({'ok': true}));
      await subject.getJson('/albums');

      expect(
        requests.single.url.toString(),
        'https://example.com/photonest/api/albums',
      );
    });

    test('fails loudly when no endpoint is stored', () async {
      endpoints = FakeApiEndpointRepository();
      final subject = client((request) async => json({}));
      await expectLater(
        subject.getJson('/albums'),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('authentication', () {
    test('attaches the bearer token to authenticated requests', () async {
      final subject = client((request) async => json({'ok': true}));
      await subject.getJson('/albums');

      expect(
        requests.single.headers['Authorization'],
        'Bearer ${testAuthSession.accessToken}',
      );
    });

    test('an unauthenticated call carries no token', () async {
      final subject = client((request) async => json({'ok': true}));
      await subject.postJson('/auth/login', {}, authenticated: false);

      expect(requests.single.headers['Authorization'], isNull);
    });

    test('throws AuthenticationError when nobody is signed in', () async {
      sessions = FakeSessionRepository();
      final subject = client((request) async => json({}));
      await expectLater(
        subject.getJson('/albums'),
        throwsA(isA<AuthenticationError>()),
      );
    });

    test(
      'a 401 triggers a refresh, persists the rotated pair, and retries', //
      () async {
        var albumCalls = 0;
        final subject = client((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            expect(jsonDecode(request.body), {
              'refresh_token': testAuthSession.refreshToken,
            });
            return json({
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
              'scope': 'gui:view album:view',
            });
          }
          albumCalls++;
          if (albumCalls == 1) {
            return json({
              'detail': {'error': 'invalid_token', 'message': 'expired'},
            }, status: 401);
          }
          return json({'items': <Object>[]});
        });

        final payload = await subject.getJson('/albums');

        expect(payload['items'], isEmpty);
        expect(albumCalls, 2);
        // The rotated pair must be stored — the server forgot the old one.
        expect(sessions.load()?.accessToken, 'access-2');
        expect(sessions.load()?.refreshToken, 'refresh-2');
        expect(sessions.load()?.scopes, ['gui:view', 'album:view']);
        // The retry carries the fresh token.
        expect(requests.last.headers['Authorization'], 'Bearer access-2');
      },
    );

    test('a failed refresh surfaces as AuthenticationError and clears the '
        'stored session', () async {
      final subject = client((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return json({
            'detail': {'error': 'invalid_token', 'message': 'revoked'},
          }, status: 401);
        }
        return json({
          'detail': {'error': 'invalid_token', 'message': 'expired'},
        }, status: 401);
      });

      await expectLater(
        subject.getJson('/albums'),
        throwsA(
          isA<AuthenticationError>().having(
            (error) => error.code,
            'code',
            'invalid_token',
          ),
        ),
      );
      // A dead refresh token can never work again: keeping the session
      // would strand the user behind an authenticated-looking UI.
      expect(sessions.load(), isNull);
      expect(sessions.cleared, 1);
    });

    test('concurrent 401s share one refresh instead of racing the rotating '
        'token', () async {
      var refreshCalls = 0;
      final subject = client((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          // Only the stored (newest) refresh token is valid — a second
          // independent refresh with the same token would fail exactly the
          // way the rotating server does.
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['refresh_token'] != sessions.load()?.refreshToken) {
            return json({
              'detail': {'error': 'invalid_token', 'message': 'rotated away'},
            }, status: 401);
          }
          return json({
            'access_token': 'access-${refreshCalls + 1}',
            'refresh_token': 'refresh-${refreshCalls + 1}',
            'scope': 'gui:view',
          });
        }
        if (request.headers['Authorization'] ==
            'Bearer ${testAuthSession.accessToken}') {
          return json({
            'detail': {'error': 'invalid_token', 'message': 'expired'},
          }, status: 401);
        }
        return json({'ok': true});
      });

      final results = await Future.wait([
        subject.getJson('/albums'),
        subject.getJson('/media'),
        subject.getJson('/albums/1'),
      ]);

      expect(results, everyElement({'ok': true}));
      expect(refreshCalls, 1);
    });
  });

  group('error mapping', () {
    test('surfaces the server detail payload', () async {
      final subject = client(
        (request) async => json({
          'detail': {'error': 'not_found', 'message': 'Album not found.'},
        }, status: 404),
      );

      await expectLater(
        subject.getJson('/albums/9'),
        throwsA(
          isA<InfrastructureError>()
              .having((error) => error.code, 'code', 'not_found')
              .having((error) => error.message, 'message', 'Album not found.'),
        ),
      );
    });

    test('tolerates a non-JSON error body', () async {
      final subject = client(
        (request) async => http.Response('<html>proxy error</html>', 502),
      );
      await expectLater(
        subject.getJson('/albums'),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('maps a network failure to InfrastructureError', () async {
      final subject = client(
        (request) async => throw http.ClientException('refused'),
      );
      await expectLater(
        subject.getJson('/albums'),
        throwsA(isA<InfrastructureError>()),
      );
    });

    test('rejects a non-object JSON response', () async {
      final subject = client((request) async => http.Response('[1,2]', 200));
      await expectLater(
        subject.getJson('/albums'),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  group('payload helpers', () {
    test('getBytes returns the raw body', () async {
      final subject = client(
        (request) async => http.Response.bytes([1, 2, 3], 200),
      );
      expect(await subject.getBytes('/media/1/thumbnail'), [1, 2, 3]);
    });

    test('postJson sends a JSON body and content type', () async {
      final subject = client((request) async => json({'ok': true}));
      await subject.postJson('/auth/login', {'email': 'a@b.c'});

      expect(
        requests.single.headers['Content-Type'],
        startsWith('application/json'),
      );
      expect(jsonDecode(requests.single.body), {'email': 'a@b.c'});
    });
  });
}
