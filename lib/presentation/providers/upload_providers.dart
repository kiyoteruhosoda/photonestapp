import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/services/auto_upload_coordinator.dart';
import 'package:flutterbase/application/usecases/upload/dismiss_upload_failures_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_unmetered_only_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_failures_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_unmetered_only_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/watch_upload_failures_usecase.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/entities/upload_failure.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/session_providers.dart';

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

final Provider<GetAutoUploadUnmeteredOnlyUseCase>
getAutoUploadUnmeteredOnlyUseCaseProvider =
    Provider<GetAutoUploadUnmeteredOnlyUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getAutoUploadUnmeteredOnlyUseCaseProvider'),
      );
    });

final Provider<SetAutoUploadUnmeteredOnlyUseCase>
setAutoUploadUnmeteredOnlyUseCaseProvider =
    Provider<SetAutoUploadUnmeteredOnlyUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('setAutoUploadUnmeteredOnlyUseCaseProvider'),
      );
    });

final Provider<ListUploadFailuresUseCase> listUploadFailuresUseCaseProvider =
    Provider<ListUploadFailuresUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listUploadFailuresUseCaseProvider'),
      );
    });

final Provider<WatchUploadFailuresUseCase> watchUploadFailuresUseCaseProvider =
    Provider<WatchUploadFailuresUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('watchUploadFailuresUseCaseProvider'),
      );
    });

final Provider<DismissUploadFailuresUseCase>
dismissUploadFailuresUseCaseProvider = Provider<DismissUploadFailuresUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('dismissUploadFailuresUseCaseProvider'),
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
    // The "uploaded" badges come from the account-scoped upload history, so
    // the grid is identity-derived even though the photos are local.
    ref.watch(sessionIdentityProvider);
    return ref.read(listUploadCandidatesUseCaseProvider).execute();
  }

  /// Re-queries the device library (also re-requests access).
  Future<void> reload() async {
    state = const AsyncValue<UploadCandidates>.loading();
    state = await AsyncValue.guard(
      () => ref.read(listUploadCandidatesUseCaseProvider).execute(),
    );
  }
}

/// One manual upload batch as the screen sees it: whether one is running,
/// how far it got, and — once it settles — its outcome.
final class UploadRunState {
  const UploadRunState({
    this.running = false,
    this.completed = 0,
    this.total = 0,
    this.fileName = '',
    this.fraction,
    this.lastResult,
  });

  /// True while a batch is in flight.
  final bool running;

  /// Photos settled so far (uploaded or failed).
  final int completed;

  /// Batch size of the running (or last) upload.
  final int total;

  /// The photo currently being sent, while one is.
  final String fileName;

  /// How far the batch has got, 0…1, counting the bytes of the photo in
  /// flight — null while nothing has been reported yet, which a bar shows
  /// as indeterminate. A single long video would otherwise leave the bar
  /// pinned at the same value for minutes.
  final double? fraction;

  /// Outcome of the most recent batch, cleared when the next one starts
  /// or via [UploadRunNotifier.dismissResult].
  final UploadPhotosResult? lastResult;
}

/// Runs one manual upload batch at a time, exposing progress, cancellation,
/// and the failure list of the last run.
final NotifierProvider<UploadRunNotifier, UploadRunState> uploadRunProvider =
    NotifierProvider<UploadRunNotifier, UploadRunState>(UploadRunNotifier.new);

/// Drives [uploadRunProvider].
class UploadRunNotifier extends Notifier<UploadRunState> {
  UploadCancellation? _cancellation;

  @override
  UploadRunState build() => const UploadRunState();

  /// Uploads [photos], reporting progress through the state, then re-reads
  /// the candidate grid so fresh "uploaded" badges come from the history
  /// rather than from patched in-memory state.
  Future<UploadPhotosResult> start(List<LocalPhoto> photos) async {
    final cancellation = UploadCancellation();
    _cancellation = cancellation;
    state = UploadRunState(running: true, total: photos.length);
    try {
      final result = await ref
          .read(uploadPhotosUseCaseProvider)
          .execute(
            photos,
            onProgress: (progress) => state = UploadRunState(
              running: true,
              completed: progress.completed,
              total: progress.total,
              fileName: progress.fileName,
              fraction: progress.fraction,
            ),
            cancellation: cancellation,
          );
      await ref.read(uploadCandidatesProvider.notifier).reload();
      state = UploadRunState(total: photos.length, lastResult: result);
      return result;
    } catch (_) {
      // An unexpected escape must not leave the screen stuck in "running";
      // the exception itself still propagates.
      state = const UploadRunState();
      rethrow;
    } finally {
      _cancellation = null;
    }
  }

  /// Asks the running batch to stop before its next photo. No-op when
  /// nothing is running.
  void cancel() => _cancellation?.cancel();

  /// Clears the last outcome — the screen calls this when the user dismisses
  /// the failure summary.
  void dismissResult() => state = const UploadRunState();
}

/// The photos that are currently failing to upload, kept across restarts.
///
/// Follows the store's change stream, so writes made **in this isolate** —
/// a manual batch, or a foreground auto-upload pass — update the list at
/// once. WorkManager's headless engine has its own repository instance and
/// its own controller, so its writes are invisible here; [refresh] is what
/// picks those up, and the composition root calls it whenever the app comes
/// back to the foreground.
final AsyncNotifierProvider<UploadFailuresNotifier, List<UploadFailure>>
uploadFailuresProvider =
    AsyncNotifierProvider<UploadFailuresNotifier, List<UploadFailure>>(
      UploadFailuresNotifier.new,
    );

/// Drives [uploadFailuresProvider].
class UploadFailuresNotifier extends AsyncNotifier<List<UploadFailure>> {
  @override
  Future<List<UploadFailure>> build() {
    // Failures are recorded per account, so signing in elsewhere must not
    // show the previous account's problems.
    ref.watch(sessionIdentityProvider);
    final subscription = ref
        .read(watchUploadFailuresUseCaseProvider)
        .execute()
        .listen((_) => unawaited(_reread()));
    ref.onDispose(subscription.cancel);
    return ref.read(listUploadFailuresUseCaseProvider).execute();
  }

  /// Forgets every recorded failure.
  Future<void> dismissAll() async {
    await ref.read(dismissUploadFailuresUseCaseProvider).execute();
    await _reread();
  }

  /// Re-reads the store. The way writes from another isolate — the
  /// background upload engine — reach this list.
  Future<void> refresh() => _reread();

  Future<void> _reread() async {
    state = await AsyncValue.guard(
      () => ref.read(listUploadFailuresUseCaseProvider).execute(),
    );
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

/// Whether auto-upload waits for an unmetered connection, together with the
/// command to change it.
final NotifierProvider<AutoUploadUnmeteredOnlyNotifier, bool>
autoUploadUnmeteredOnlyProvider =
    NotifierProvider<AutoUploadUnmeteredOnlyNotifier, bool>(
      AutoUploadUnmeteredOnlyNotifier.new,
    );

/// Mirrors the persisted "Wi-Fi only" switch.
class AutoUploadUnmeteredOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(getAutoUploadUnmeteredOnlyUseCaseProvider).execute();

  /// Persists the choice, then pokes the coordinator: lifting the
  /// restriction while on mobile data should start uploading right away
  /// rather than at the next library change.
  Future<void> setUnmeteredOnly(bool unmeteredOnly) async {
    await ref
        .read(setAutoUploadUnmeteredOnlyUseCaseProvider)
        .execute(unmeteredOnly);
    state = unmeteredOnly;
    if (ref.read(autoUploadEnabledProvider)) {
      await ref.read(autoUploadCoordinatorProvider).triggerSync();
    }
  }
}

/// Device photo previews for the upload grid, cached per asset id.
final localThumbnailProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  localId,
) {
  return ref.read(getLocalThumbnailUseCaseProvider).execute(localId);
});
