import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/widgets/session_cache_reset.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  /// Renders the cached album count, so a test can see whether the
  /// provider rebuilt.
  Widget probe(TestScope scope) => SessionCacheReset(
    sessionViewModel: scope.sessionViewModel,
    child: Consumer(
      builder: (context, ref, _) {
        final albums = ref.watch(albumListProvider);
        return Scaffold(body: Text('albums:${albums.value?.length}'));
      },
    ),
  );

  testWidgets('a session change to another identity drops the caches', (
    tester,
  ) async {
    final scope = TestScope();
    await pumpInScope(tester, probe(scope), scope: scope);
    expect(find.text('albums:0'), findsOneWidget);

    // New data appears server-side; the cache is deliberately stale.
    scope.albumRepository.albums = [testAlbum(title: 'Fresh')];
    await tester.pump();
    expect(find.text('albums:0'), findsOneWidget);

    // Signing out is an identity change — the caches must go.
    await scope.sessionViewModel.logout();
    await tester.pumpAndSettle();
    expect(find.text('albums:1'), findsOneWidget);
  });

  testWidgets('a same-identity notification keeps the caches', (tester) async {
    final scope = TestScope(
      apiEndpointRepository: FakeApiEndpointRepository(
        Uri.parse('https://photos.example.com'),
      ),
    );
    await pumpInScope(tester, probe(scope), scope: scope);
    expect(find.text('albums:0'), findsOneWidget);

    scope.albumRepository.albums = [testAlbum(title: 'Fresh')];
    // Logging in again as the same user on the same server notifies the
    // listeners (busy flips twice) but does not change identity.
    await scope.sessionViewModel.login(
      serverUrl: 'https://photos.example.com',
      email: scope.sessionViewModel.session!.email,
      password: 'secret',
    );
    await tester.pumpAndSettle();

    expect(find.text('albums:0'), findsOneWidget);
  });
}
