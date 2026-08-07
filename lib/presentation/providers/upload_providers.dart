import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/services/auto_upload_coordinator.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────

final Provider<ListUploadCandidatesUseCase>
listUploadCandidatesUseCaseProvider = Provider<ListUploadCandidatesUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('listUploadCandidatesUseCaseProvider'),
  );
});

final Provider<UploadPhotosUseCase> uploadPhotosUseCaseProvider =
    Provider<UploadPhotosUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('uploadPhotosUseCaseProvider'),
      );
    });

final Provider<GetLocalThumbnailUseCase> getLocalThumbnailUseCaseProvider =
    Provider<GetLocalThumbnailUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getLocalThumbnailUseCaseProvider'),
      );
    });

final Provider<GetAutoUploadEnabledUseCase>
getAutoUploadEnabledUseCaseProvider = Provider<GetAutoUploadEnabledUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('getAutoUploadEnabledUseCaseProvider'),
  );
});

final Provider<SetAutoUploadEnabledUseCase>
setAutoUploadEnabledUseCaseProvider = Provider<SetAutoUploadEnabledUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('setAutoUploadEnabledUseCaseProvider'),
  );
});

/// The long-lived watcher the composition root starts at boot. The upload
/// screen pokes it after a manual toggle so new photos sync immediately.
final Provider<AutoUploadCoordinator> autoUploadCoordinatorProvider =
    Provider<AutoUploadCoordinator>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('autoUploadCoordinatorProvider'),
      );
    });

// ─── Screen state ──────────────────────────────────────────────────────────

/// Recent device photos with their upload state.
final AsyncNotifierProvider<UploadCandidatesNotifier, UploadCandidates>
uploadCandidatesProvider =
    AsyncNotifierProvider<UploadCandidatesNotifier, UploadCandidates>(
      UploadCandidatesNotifier.new,
    );

/// Loads the recent photos, and uploads a selection.
class UploadCandidatesNotifier extends AsyncNotifier<UploadCandidates> {
  @override
  Future<UploadCandidates> build() {
    return ref.read(listUploadCandidatesUseCaseProvider).execute();
  }

  /// Re-queries the device library (also re-requests access).
  Future<void> reload() async {
    state = const AsyncValue<UploadCandidates>.loading();
    state = await AsyncValue.guard(
      () => ref.read(listUploadCandidatesUseCaseProvider).execute(),
    );
  }

  /// Uploads [photos], then re-reads the grid so fresh "uploaded" badges
  /// come from the history rather than from patched in-memory state.
  Future<UploadPhotosResult> upload(List<LocalPhoto> photos) async {
    final result = await ref.read(uploadPhotosUseCaseProvider).execute(photos);
    await reload();
    return result;
  }
}

/// Whether auto-upload is on, together with the command to change it.
final NotifierProvider<AutoUploadEnabledNotifier, bool>
autoUploadEnabledProvider = NotifierProvider<AutoUploadEnabledNotifier, bool>(
  AutoUploadEnabledNotifier.new,
);

/// Mirrors the persisted auto-upload switch.
class AutoUploadEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(getAutoUploadEnabledUseCaseProvider).execute();

  /// Returns the effective state — switching on can be refused when the
  /// user denies photo access. Switching on also triggers a sync pass so
  /// the effect is visible immediately.
  Future<bool> setEnabled(bool enabled) async {
    final effective = await ref
        .read(setAutoUploadEnabledUseCaseProvider)
        .execute(enabled);
    state = effective;
    if (effective) {
      await ref.read(autoUploadCoordinatorProvider).triggerSync();
    }
    return effective;
  }
}

/// Device photo previews for the upload grid, cached per asset id.
final localThumbnailProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  localId,
) {
  return ref.read(getLocalThumbnailUseCaseProvider).execute(localId);
});
