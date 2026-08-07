import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/albums/albums_tab.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  testWidgets('shows the empty state when the server has no albums', (
    tester,
  ) async {
    await pumpInScope(tester, const Scaffold(body: AlbumsTab()));
    expect(find.textContaining(l10n.albumsEmpty), findsOneWidget);
  });

  testWidgets('shows the error state with a retry that reloads', (
    tester,
  ) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository()
        ..failure = const InfrastructureError('server down'),
    );
    await pumpInScope(tester, const Scaffold(body: AlbumsTab()), scope: scope);
    expect(find.text('server down'), findsOneWidget);

    // The next load succeeds — retry must recover, not stay stuck.
    scope.albumRepository
      ..failure = null
      ..albums = [testAlbum(title: 'Recovered', coverMediaId: null)];
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('renders a card per album with title and count', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        albums: [
          testAlbum(id: 1, title: 'Trip', mediaCount: 2),
          testAlbum(id: 2, title: 'Cats', mediaCount: 1, coverMediaId: null),
        ],
      ),
    );
    await pumpInScope(tester, const Scaffold(body: AlbumsTab()), scope: scope);

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text(l10n.albumsMediaCount(2)), findsOneWidget);
    expect(find.text(l10n.albumsMediaCount(1)), findsOneWidget);
    // The covered album fetched its thumbnail; the bare one shows the icon.
    expect(scope.mediaThumbnailRepository.fetched, hasLength(1));
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
  });

  testWidgets('tapping an album navigates to its detail route', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        albums: [testAlbum(id: 5, title: 'Trip', coverMediaId: null)],
      ),
    );
    await pumpInScope(tester, const Scaffold(body: AlbumsTab()), scope: scope);

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    expect(scope.location, '/albums/5');
  });
}
