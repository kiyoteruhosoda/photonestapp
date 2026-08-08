import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/upload/upload_tab.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  TestScope scopeWithPhotos(List<String> ids, {Set<String>? uploaded}) {
    final photoLibrary = FakePhotoLibraryGateway(
      photos: [for (final id in ids) testLocalPhoto(localId: id)],
    );
    for (final id in ids) {
      photoLibrary.bytesById[id] = Uint8List.fromList([1]);
      photoLibrary.thumbnailsById[id] = testPngBytes;
    }
    return TestScope(
      photoLibrary: photoLibrary,
      uploadHistoryRepository: FakeUploadHistoryRepository(uploaded),
    );
  }

  testWidgets('denied access shows the permission state, and retry re-asks', (
    tester,
  ) async {
    final scope = TestScope(
      photoLibrary: FakePhotoLibraryGateway(accessGranted: false),
    );
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    expect(find.textContaining(l10n.uploadPermissionTitle), findsOneWidget);
    final asked = scope.photoLibrary.accessRequests;

    scope.photoLibrary.accessGranted = true;
    await tester.tap(find.text(l10n.uploadPermissionRetry));
    await tester.pumpAndSettle();

    expect(scope.photoLibrary.accessRequests, greaterThan(asked));
    expect(find.text(l10n.uploadEmpty), findsOneWidget);
  });

  testWidgets('an empty library shows the empty state', (tester) async {
    await pumpInScope(tester, const Scaffold(body: UploadTab()));
    expect(find.text(l10n.uploadEmpty), findsOneWidget);
  });

  testWidgets('selecting photos enables the upload button and uploads them', (
    tester,
  ) async {
    final scope = scopeWithPhotos(['a', 'b']);
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    expect(find.byType(ThumbnailImage), findsNWidgets(2));
    // Nothing selected yet — the button is disabled.
    final button = tester.widget<AppPrimaryButton>(
      find.byType(AppPrimaryButton),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(ThumbnailImage).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadSelectedCount(1)), findsOneWidget);

    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(scope.photoUploadRepository.uploaded, hasLength(1));
    expect(find.text(l10n.uploadDone(1)), findsOneWidget);
    // The grid reloaded from the history: the sent photo is badged now.
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('tapping a selected photo deselects it', (tester) async {
    final scope = scopeWithPhotos(['a']);
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    await tester.tap(find.byType(ThumbnailImage));
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadSelectedCount(1)), findsOneWidget);

    await tester.tap(find.byType(ThumbnailImage));
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadSelectedCount(1)), findsNothing);
  });

  testWidgets('already-uploaded photos are badged and not selectable', (
    tester,
  ) async {
    final scope = scopeWithPhotos(['done'], uploaded: {'done'});
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    await tester.tap(find.byType(ThumbnailImage));
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadSelectedCount(1)), findsNothing);
  });

  testWidgets('failures are reported alongside successes', (tester) async {
    final scope = scopeWithPhotos(['good', 'bad']);
    scope.photoUploadRepository
      ..failure = const InfrastructureError('too large')
      ..failFor = {'bad'};
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    await tester.tap(find.byType(ThumbnailImage).at(0));
    await tester.tap(find.byType(ThumbnailImage).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    // Once in the snackbar, once in the failure summary under the grid.
    expect(find.textContaining(l10n.uploadFailed(1)), findsNWidgets(2));
    expect(scope.photoUploadRepository.uploaded, hasLength(1));
  });

  testWidgets('the failure summary opens a translated per-photo list', (
    tester,
  ) async {
    final scope = scopeWithPhotos(['bad']);
    scope.photoUploadRepository.failure = const InfrastructureError('HTTP 500');
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    await tester.tap(find.byType(ThumbnailImage));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.uploadShowFailures));
    await tester.pumpAndSettle();

    expect(find.text(l10n.uploadFailureListTitle), findsOneWidget);
    expect(find.text('IMG_0001.jpg'), findsOneWidget);
    // The reason is translated; the raw server message stays out of the UI.
    expect(find.text(l10n.uploadFailureRejected), findsOneWidget);
    expect(find.text('HTTP 500'), findsNothing);

    await tester.tap(find.text(l10n.commonClose));
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadFailureListTitle), findsNothing);

    // The summary can be dismissed once read.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(l10n.uploadShowFailures), findsNothing);
  });

  testWidgets('a running batch shows progress and can be cancelled', (
    tester,
  ) async {
    final scope = scopeWithPhotos(['a', 'b', 'c']);
    var gate = Completer<void>();
    scope.photoUploadRepository.gate = (_) => gate.future;
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(ThumbnailImage).at(i));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(l10n.uploadProgress(0, 3)), findsOneWidget);

    // Cancel while the first photo is still in flight: it completes, the
    // remaining two are never attempted.
    await tester.tap(find.text(l10n.uploadCancel));
    final released = gate;
    gate = Completer<void>()..complete();
    released.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining(l10n.uploadCancelled), findsOneWidget);
    expect(scope.photoUploadRepository.uploaded, hasLength(1));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the auto-upload switch persists and reports denial', (
    tester,
  ) async {
    final scope = TestScope();
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(scope.autoUploadSettingsRepository.enabled, isTrue);

    // Turning it on while access is denied snaps back with an explanation.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    scope.photoLibrary.accessGranted = false;
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(scope.autoUploadSettingsRepository.enabled, isFalse);
    expect(find.text(l10n.uploadAutoDenied), findsOneWidget);
  });

  testWidgets('a video candidate carries the play badge', (tester) async {
    final photoLibrary = FakePhotoLibraryGateway(
      photos: [
        testLocalPhoto(localId: 'p1'),
        testLocalPhoto(localId: 'v1', fileName: 'clip.mp4', isVideo: true),
      ],
    );
    photoLibrary.thumbnailsById['p1'] = testPngBytes;
    photoLibrary.thumbnailsById['v1'] = testPngBytes;
    final scope = TestScope(photoLibrary: photoLibrary);
    await pumpInScope(tester, const Scaffold(body: UploadTab()), scope: scope);

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
