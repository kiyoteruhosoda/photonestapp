// `Override` — the type `ProviderScope.overrides` takes — lives in Riverpod's
// `misc.dart` rather than its main entry point.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/services/auto_upload_coordinator.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/open_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';
import 'package:flutterbase/presentation/providers/upload_providers.dart';

/// Bridges the service locator to Riverpod.
///
/// The providers in `presentation/providers/` declare *what* a screen needs
/// and throw if read un-overridden; this list is the only place that says
/// *which* instance satisfies each one. Keeping the bridge in the composition
/// root is what lets Presentation stay unaware of `get_it`, and what makes a
/// widget test able to swap any single use case for a fake by overriding the
/// same provider.
List<Override> buildProviderOverrides() {
  return <Override>[
    appLoggerProvider.overrideWithValue(sl<AppLogger>()),
    listBookmarksUseCaseProvider.overrideWithValue(sl<ListBookmarksUseCase>()),
    getBookmarkUseCaseProvider.overrideWithValue(sl<GetBookmarkUseCase>()),
    addBookmarkUseCaseProvider.overrideWithValue(sl<AddBookmarkUseCase>()),
    removeBookmarkUseCaseProvider.overrideWithValue(
      sl<RemoveBookmarkUseCase>(),
    ),
    openBookmarkUseCaseProvider.overrideWithValue(sl<OpenBookmarkUseCase>()),
    listAlbumsUseCaseProvider.overrideWithValue(sl<ListAlbumsUseCase>()),
    getAlbumUseCaseProvider.overrideWithValue(sl<GetAlbumUseCase>()),
    getMediaThumbnailUseCaseProvider.overrideWithValue(
      sl<GetMediaThumbnailUseCase>(),
    ),
    listUploadCandidatesUseCaseProvider.overrideWithValue(
      sl<ListUploadCandidatesUseCase>(),
    ),
    uploadPhotosUseCaseProvider.overrideWithValue(sl<UploadPhotosUseCase>()),
    getLocalThumbnailUseCaseProvider.overrideWithValue(
      sl<GetLocalThumbnailUseCase>(),
    ),
    getAutoUploadEnabledUseCaseProvider.overrideWithValue(
      sl<GetAutoUploadEnabledUseCase>(),
    ),
    setAutoUploadEnabledUseCaseProvider.overrideWithValue(
      sl<SetAutoUploadEnabledUseCase>(),
    ),
    autoUploadCoordinatorProvider.overrideWithValue(
      sl<AutoUploadCoordinator>(),
    ),
  ];
}
