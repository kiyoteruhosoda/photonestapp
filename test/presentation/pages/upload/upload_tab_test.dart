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

    expect(find.textContaining(l10n.uploadFailed(1)), findsOneWidget);
    expect(scope.photoUploadRepository.uploaded, hasLength(1));
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
}
