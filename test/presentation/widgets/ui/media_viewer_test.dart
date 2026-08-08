import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  List<MediaItem> photos(int count) => [
    for (var i = 1; i <= count; i++) testMediaItem(id: i, filename: 'IMG_$i'),
  ];

  /// Pumps a screen whose only job is to open the viewer.
  Future<TestScope> openViewer(
    WidgetTester tester, {
    required List<MediaItem> items,
    int initialIndex = 0,
    TestScope? scope,
  }) async {
    final used = scope ?? TestScope();
    await pumpInScope(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMediaViewer(
              context,
              items: items,
              initialIndex: initialIndex,
            ),
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

  testWidgets('opens on the tapped item and names its position', (
    tester,
  ) async {
    await openViewer(tester, items: photos(3), initialIndex: 1);

    expect(find.text(l10n.mediaViewerPosition(2, 3)), findsOneWidget);
  });

  testWidgets('swiping moves to the next photo', (tester) async {
    final scope = await openViewer(tester, items: photos(3), initialIndex: 0);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mediaViewerPosition(2, 3)), findsOneWidget);
    // The neighbour's rendition was fetched, so the swipe really moved.
    expect(
      scope.mediaThumbnailRepository.fetched.map((entry) => entry.$1.value),
      contains(2),
    );
  });

  testWidgets('the original is only requested when asked for', (tester) async {
    final scope = await openViewer(tester, items: photos(1));
    expect(scope.mediaOriginalRepository.downloaded, isEmpty);

    await tester.tap(find.byIcon(Icons.hd_outlined));
    await tester.pumpAndSettle();

    // The signed URL was issued; streaming the bytes is Flutter's job, and
    // the test binding refuses real requests, so the viewer draws its
    // "could not load" state rather than throwing.
    expect(scope.mediaOriginalRepository.requested.single.value, 1);
    expect(find.text(l10n.mediaOriginalUnavailable), findsOneWidget);
  });

  testWidgets('a video page asks for a playback source, not a rendition', (
    tester,
  ) async {
    final scope = TestScope();
    await openViewer(
      tester,
      items: [testMediaItem(id: 7, filename: 'clip.mp4', isVideo: true)],
      scope: scope,
    );

    expect(scope.mediaPlaybackRepository.requested, hasLength(1));
    // A video has no still original to swap in, so the action is inert.
    final showOriginal = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.hd_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(showOriginal.onPressed, isNull);
  });

  testWidgets('saving downloads the original and files it on the device', (
    tester,
  ) async {
    final scope = await openViewer(tester, items: photos(1));

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(scope.mediaOriginalRepository.downloaded.single.value, 1);
    expect(scope.photoLibrary.savedToLibrary.single.$1, 'IMG_1');
    expect(find.text(l10n.mediaSaveDone), findsOneWidget);
  });

  testWidgets('a save that cannot download says so', (tester) async {
    final scope = TestScope();
    scope.mediaOriginalRepository.failure = const NetworkUnreachableError(
      'offline',
    );
    await openViewer(tester, items: photos(1), scope: scope);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(scope.photoLibrary.savedToLibrary, isEmpty);
    expect(find.text(l10n.mediaSaveDownloadFailed), findsOneWidget);
  });

  testWidgets('a denied library grant is reported before any download', (
    tester,
  ) async {
    final scope = TestScope(
      photoLibrary: FakePhotoLibraryGateway(accessGranted: false),
    );
    await openViewer(tester, items: photos(1), scope: scope);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    // Nothing was downloaded — the grant is checked first, so a refusal
    // does not cost a whole original's worth of traffic.
    expect(scope.mediaOriginalRepository.downloaded, isEmpty);
    expect(find.text(l10n.mediaSaveNoAccess), findsOneWidget);
  });

  testWidgets('the close button dismisses the viewer', (tester) async {
    await openViewer(tester, items: photos(2));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
  });
}
