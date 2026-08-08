import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/albums/album_detail_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  AlbumDetail detail({int mediaCount = 2}) => AlbumDetail(
    album: testAlbum(id: 3, title: 'Holiday'),
    media: [
      for (var i = 1; i <= mediaCount; i++)
        testAlbumMediaItem(id: i, filename: 'IMG_$i.jpg'),
    ],
  );

  testWidgets('a null id renders the not-found state', (tester) async {
    await pumpInScope(tester, const AlbumDetailPage(id: null));
    expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
  });

  testWidgets('an unknown album renders the not-found state', (tester) async {
    final scope = TestScope();
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(9)), scope: scope);
    expect(find.textContaining(l10n.albumNotFound), findsOneWidget);
  });

  testWidgets('shows the title and one tile per media item', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(details: {AlbumId(3): detail()}),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    expect(find.text('Holiday'), findsOneWidget);
    expect(find.byType(ThumbnailImage), findsNWidgets(2));
    expect(scope.mediaThumbnailRepository.fetched, hasLength(2));
  });

  testWidgets('an album with no media shows the empty state', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {AlbumId(3): detail(mediaCount: 0)},
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);
    expect(find.text(l10n.albumEmpty), findsOneWidget);
  });

  testWidgets('a failing load renders the error state', (tester) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository()
        ..failure = const InfrastructureError('boom'),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);
    expect(find.text('boom'), findsNothing);
    // A response the server did send (not a transport failure) stays
    // generic rather than telling the user to check their connection.
    expect(find.text(l10n.commonError), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });

  testWidgets('tapping a tile opens the full-screen preview and taps close', (
    tester,
  ) async {
    final scope = TestScope(
      albumRepository: FakeAlbumRepository(
        details: {AlbumId(3): detail(mediaCount: 1)},
      ),
    );
    await pumpInScope(tester, AlbumDetailPage(id: AlbumId(3)), scope: scope);

    await tester.tap(find.byType(ThumbnailImage).first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    // The preview asks for the large rendition.
    expect(
      scope.mediaThumbnailRepository.fetched.map((entry) => entry.$2),
      contains(2048),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
