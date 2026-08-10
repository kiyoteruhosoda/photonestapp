import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  /// Pumps a screen whose only job is to open the picker for one photo.
  Future<TestScope> openPicker(
    WidgetTester tester, {
    TestScope? scope,
    int mediaId = 5,
  }) async {
    final used = scope ?? TestScope();
    await pumpInScope(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAlbumPicker(context, mediaId: MediaId(mediaId)),
            child: const Text('open'),
          ),
        ),
      ),
      scope: used,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return used;
  }

  TestScope scopeWithAlbums({
    List<Album>? albums,
    Map<AlbumId, List<MediaId>>? holding,
  }) {
    return TestScope(
      albumRepository: FakeAlbumRepository(
        albums: albums ?? [testAlbum(id: 4, title: 'Trip', mediaCount: 2)],
      ),
      albumEditingRepository: FakeAlbumEditingRepository(mediaIds: holding),
    );
  }

  testWidgets('files the photo into the album the reader taps', (tester) async {
    final scope = await openPicker(
      tester,
      scope: scopeWithAlbums(
        holding: {
          AlbumId(4): <MediaId>[MediaId(1)],
        },
      ),
    );

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    // What the album already held is sent back with the new photo appended
    // — the endpoint replaces the whole set.
    expect(scope.albumEditingRepository.replaced.single.mediaIds, [
      MediaId(1),
      MediaId(5),
    ]);
    expect(find.text(l10n.albumAddedTo('Trip')), findsOneWidget);
  });

  testWidgets('says so rather than claiming a second copy was added', (
    tester,
  ) async {
    await openPicker(
      tester,
      scope: scopeWithAlbums(
        holding: {
          AlbumId(4): <MediaId>[MediaId(5)],
        },
      ),
    );

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.albumAlreadyContains('Trip')), findsOneWidget);
  });

  testWidgets('reports a failure and leaves the sheet open', (tester) async {
    final scope = scopeWithAlbums();
    scope.albumEditingRepository.failure = const NetworkUnreachableError(
      'offline',
    );
    await openPicker(tester, scope: scope);

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.albumAddFailed), findsOneWidget);
    expect(find.text(l10n.albumPickerTitle), findsOneWidget);
  });

  testWidgets('offers to make an album that holds the photo', (tester) async {
    final scope = await openPicker(
      tester,
      scope: scopeWithAlbums(albums: <Album>[]),
    );

    expect(find.textContaining(l10n.albumPickerEmpty), findsOneWidget);

    await tester.tap(find.text(l10n.albumPickerNewAlbum));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.albumNameLabel),
      'Kyoto',
    );
    await tester.tap(find.text(l10n.albumCreateAction));
    await tester.pumpAndSettle();

    // One request: the album arrives with the photo already in it, so
    // there is no window where it exists empty.
    expect(scope.albumEditingRepository.created.single.mediaIds, [MediaId(5)]);
    expect(scope.albumEditingRepository.replaced, isEmpty);
  });

  testWidgets('hides the new-album row without album:create', (tester) async {
    await openPicker(
      tester,
      scope: TestScope(
        sessionRepository: FakeSessionRepository(
          AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            email: 'reader@example.com',
            scopes: const [
              'gui:view',
              'album:view',
              'media:view',
              'album:edit',
            ],
          ),
        ),
        albumRepository: FakeAlbumRepository(
          albums: [testAlbum(id: 4, title: 'Trip')],
        ),
      ),
    );

    // Filing into an album that exists needs only album:edit, so the list
    // is still there — it is the creating that is not offered.
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text(l10n.albumPickerNewAlbum), findsNothing);
  });
}
