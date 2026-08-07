import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/app/bootstrap/app_router.dart';
import 'package:flutterbase/application/services/auto_upload_coordinator.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:flutterbase/application/usecases/auth/login_usecase.dart';
import 'package:flutterbase/application/usecases/auth/logout_usecase.dart';
import 'package:flutterbase/application/usecases/auth/restore_session_usecase.dart';
import 'package:flutterbase/application/usecases/auth/watch_session_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/open_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/application/usecases/language/get_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/language/set_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/theme/get_theme_preference_usecase.dart';
import 'package:flutterbase/application/usecases/theme/set_theme_preference_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:flutterbase/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:flutterbase/application/usecases/upload/upload_photos_usecase.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/providers/app_info_providers.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';
import 'package:flutterbase/presentation/providers/session_providers.dart';
import 'package:flutterbase/presentation/providers/settings_providers.dart';
import 'package:flutterbase/presentation/providers/upload_providers.dart';
import 'package:flutterbase/presentation/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';
import 'recording_app_logger.dart';

/// A fully wired Presentation dependency set, built from in-memory fakes.
///
/// Mirrors what `app/di/service_locator.dart` and
/// `app/di/provider_overrides.dart` assemble at runtime, so a widget test
/// exercises the same wiring the app ships — without any platform channel.
/// All screen state lives in Riverpod; [container] is the test's window into
/// it (`scope.container.read(themeModeProvider)` and friends).
class TestScope {
  TestScope({
    FakeThemePreferenceRepository? themeRepository,
    FakeLanguagePreferenceRepository? languageRepository,
    FakeDebugSettingsRepository? debugSettingsRepository,
    FakeAppInfoRepository? appInfoRepository,
    FakeBookmarkRepository? bookmarkRepository,
    RecordingExternalLinkLauncher? linkLauncher,
    RecordingAppLogger? logger,
    FakeAuthRepository? authRepository,
    FakeSessionRepository? sessionRepository,
    FakeApiEndpointRepository? apiEndpointRepository,
    FakeAlbumRepository? albumRepository,
    FakeMediaThumbnailRepository? mediaThumbnailRepository,
    FakePhotoUploadRepository? photoUploadRepository,
    FakeUploadHistoryRepository? uploadHistoryRepository,
    FakeAutoUploadSettingsRepository? autoUploadSettingsRepository,
    FakePhotoLibraryGateway? photoLibrary,
    AuthSession? initialSession,
  }) : themeRepository = themeRepository ?? FakeThemePreferenceRepository(),
       languageRepository =
           languageRepository ?? FakeLanguagePreferenceRepository(),
       debugSettingsRepository =
           debugSettingsRepository ?? FakeDebugSettingsRepository(),
       appInfoRepository = appInfoRepository ?? FakeAppInfoRepository(),
       bookmarkRepository = bookmarkRepository ?? FakeBookmarkRepository(),
       linkLauncher = linkLauncher ?? RecordingExternalLinkLauncher(),
       logger = logger ?? RecordingAppLogger(),
       authRepository = authRepository ?? FakeAuthRepository(),
       // Widget tests exercise screens that sit behind the login guard, so
       // the default scope is signed in; pass a fresh FakeSessionRepository
       // to start signed out.
       sessionRepository =
           sessionRepository ??
           FakeSessionRepository(initialSession ?? testAuthSession),
       apiEndpointRepository =
           apiEndpointRepository ?? FakeApiEndpointRepository(),
       albumRepository = albumRepository ?? FakeAlbumRepository(),
       mediaThumbnailRepository =
           mediaThumbnailRepository ?? FakeMediaThumbnailRepository(),
       photoUploadRepository =
           photoUploadRepository ?? FakePhotoUploadRepository(),
       uploadHistoryRepository =
           uploadHistoryRepository ?? FakeUploadHistoryRepository(),
       autoUploadSettingsRepository =
           autoUploadSettingsRepository ?? FakeAutoUploadSettingsRepository(),
       photoLibrary = photoLibrary ?? FakePhotoLibraryGateway();

  final FakeThemePreferenceRepository themeRepository;
  final FakeLanguagePreferenceRepository languageRepository;
  final FakeDebugSettingsRepository debugSettingsRepository;
  final FakeAppInfoRepository appInfoRepository;
  final FakeBookmarkRepository bookmarkRepository;
  final RecordingExternalLinkLauncher linkLauncher;
  final RecordingAppLogger logger;
  final FakeAuthRepository authRepository;
  final FakeSessionRepository sessionRepository;
  final FakeApiEndpointRepository apiEndpointRepository;
  final FakeAlbumRepository albumRepository;
  final FakeMediaThumbnailRepository mediaThumbnailRepository;
  final FakePhotoUploadRepository photoUploadRepository;
  final FakeUploadHistoryRepository uploadHistoryRepository;
  final FakeAutoUploadSettingsRepository autoUploadSettingsRepository;
  final FakePhotoLibraryGateway photoLibrary;

  /// The Riverpod container every wrapped widget reads from.
  ///
  /// The same instance backs [wrap] (via `UncontrolledProviderScope`), so a
  /// test can drive state — `container.read(sessionProvider.notifier)` — and
  /// observe what the screen sees.
  late final ProviderContainer container = ProviderContainer(
    overrides: providerOverrides(),
    // Mirrors main.dart: no automatic retry — error states carry an
    // explicit retry button, and a background retry would double-count the
    // repository calls tests assert on.
    retry: (retryCount, error) => null,
  );

  /// Shorthand for the session commands most auth tests need.
  SessionNotifier get session => container.read(sessionProvider.notifier);

  /// The router [wrap] installed, available once [wrap] has been called.
  late final GoRouter router;

  /// Locations the router resolved, oldest first — the harness equivalent of
  /// watching the navigation stack.
  final List<String> visitedLocations = <String>[];

  /// Where the router currently is.
  String get location => router.state.uri.toString();

  /// A refresh bridge wired to [container], for tests that mount the app's
  /// real router: it re-runs the auth guard when the session changes,
  /// exactly as the composition root does at runtime.
  Listenable routerRefresh() {
    final bridge = RouterRefreshBridge();
    container.listen<bool>(
      sessionProvider.select((state) => state.isAuthenticated),
      (_, _) => bridge.poke(),
    );
    return bridge;
  }

  /// The Riverpod overrides the composition root installs, with fakes in
  /// place of the real adapters.
  List<Override> providerOverrides() {
    final uploadPhotos = UploadPhotosUseCase(
      photoLibrary,
      photoUploadRepository,
      uploadHistoryRepository,
      logger,
    );
    return <Override>[
      appLoggerProvider.overrideWithValue(logger),
      listBookmarksUseCaseProvider.overrideWithValue(
        ListBookmarksUseCase(bookmarkRepository),
      ),
      getBookmarkUseCaseProvider.overrideWithValue(
        GetBookmarkUseCase(bookmarkRepository),
      ),
      addBookmarkUseCaseProvider.overrideWithValue(
        AddBookmarkUseCase(bookmarkRepository, logger),
      ),
      removeBookmarkUseCaseProvider.overrideWithValue(
        RemoveBookmarkUseCase(bookmarkRepository, logger),
      ),
      openBookmarkUseCaseProvider.overrideWithValue(
        OpenBookmarkUseCase(linkLauncher, logger),
      ),
      listAlbumsUseCaseProvider.overrideWithValue(
        ListAlbumsUseCase(albumRepository),
      ),
      getAlbumUseCaseProvider.overrideWithValue(
        GetAlbumUseCase(albumRepository),
      ),
      getMediaThumbnailUseCaseProvider.overrideWithValue(
        GetMediaThumbnailUseCase(mediaThumbnailRepository),
      ),
      listUploadCandidatesUseCaseProvider.overrideWithValue(
        ListUploadCandidatesUseCase(photoLibrary, uploadHistoryRepository),
      ),
      uploadPhotosUseCaseProvider.overrideWithValue(uploadPhotos),
      getLocalThumbnailUseCaseProvider.overrideWithValue(
        GetLocalThumbnailUseCase(photoLibrary),
      ),
      getAutoUploadEnabledUseCaseProvider.overrideWithValue(
        GetAutoUploadEnabledUseCase(autoUploadSettingsRepository),
      ),
      setAutoUploadEnabledUseCaseProvider.overrideWithValue(
        SetAutoUploadEnabledUseCase(
          autoUploadSettingsRepository,
          photoLibrary,
          logger,
        ),
      ),
      autoUploadCoordinatorProvider.overrideWithValue(
        AutoUploadCoordinator(
          photoLibrary,
          SyncNewPhotosUseCase(
            autoUploadSettingsRepository,
            sessionRepository,
            photoLibrary,
            uploadHistoryRepository,
            uploadPhotos,
            logger,
          ),
          logger,
        ),
      ),
      getThemePreferenceUseCaseProvider.overrideWithValue(
        GetThemePreferenceUseCase(themeRepository),
      ),
      setThemePreferenceUseCaseProvider.overrideWithValue(
        SetThemePreferenceUseCase(themeRepository),
      ),
      getLanguagePreferenceUseCaseProvider.overrideWithValue(
        GetLanguagePreferenceUseCase(languageRepository),
      ),
      setLanguagePreferenceUseCaseProvider.overrideWithValue(
        SetLanguagePreferenceUseCase(languageRepository),
      ),
      getDebugSettingsUseCaseProvider.overrideWithValue(
        GetDebugSettingsUseCase(debugSettingsRepository),
      ),
      setDebugModeUseCaseProvider.overrideWithValue(
        SetDebugModeUseCase(debugSettingsRepository),
      ),
      setLogLevelUseCaseProvider.overrideWithValue(
        SetLogLevelUseCase(debugSettingsRepository, logger),
      ),
      getAppInfoUseCaseProvider.overrideWithValue(
        GetAppInfoUseCase(appInfoRepository),
      ),
      loginUseCaseProvider.overrideWithValue(
        LoginUseCase(
          authRepository,
          sessionRepository,
          apiEndpointRepository,
          logger,
        ),
      ),
      logoutUseCaseProvider.overrideWithValue(
        LogoutUseCase(authRepository, sessionRepository, logger),
      ),
      restoreSessionUseCaseProvider.overrideWithValue(
        RestoreSessionUseCase(sessionRepository),
      ),
      getApiEndpointUseCaseProvider.overrideWithValue(
        GetApiEndpointUseCase(apiEndpointRepository),
      ),
      watchSessionUseCaseProvider.overrideWithValue(
        WatchSessionUseCase(sessionRepository),
      ),
    ];
  }

  /// Wraps [child] in the same providers, theme, localisations, and router
  /// the real app installs, so a widget under test sees production
  /// conditions.
  ///
  /// [child] is mounted at `/`; every other location in
  /// [AppRoutes] resolves to a labelled placeholder, so a test asserts that
  /// navigation happened — via [location] or [visitedLocations] — rather than
  /// rebuilding the destination screen.
  Widget wrap(
    Widget child, {
    Locale? locale,
    List<NavigatorObserver>? observers,
  }) {
    return wrapRouter(
      _buildRouter(child, observers: observers),
      locale: locale,
    );
  }

  /// The same providers, theme, and localisations as [wrap], driven by
  /// [config] instead of the placeholder route table.
  ///
  /// For tests that exercise the app's real router — a deep link resolving to
  /// a real screen, for instance.
  Widget wrapRouter(GoRouter config, {Locale? locale}) {
    router = config;
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: config,
      ),
    );
  }

  GoRouter _buildRouter(Widget home, {List<NavigatorObserver>? observers}) {
    Widget placeholder(BuildContext context, GoRouterState state) =>
        Scaffold(body: Center(child: Text('route:${state.uri}')));

    return GoRouter(
      initialLocation: AppRoutes.main,
      observers: observers,
      redirect: (context, state) {
        visitedLocations.add(state.uri.toString());
        return null;
      },
      errorBuilder: placeholder,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.login, builder: placeholder),
        GoRoute(
          path: AppRoutes.main,
          builder: (context, state) => home,
          routes: <RouteBase>[
            GoRoute(path: 'about', builder: placeholder),
            GoRoute(path: 'debug', builder: placeholder),
            GoRoute(path: 'logs', builder: placeholder),
            GoRoute(path: 'link', builder: placeholder),
            GoRoute(path: 'albums/:id', builder: placeholder),
            GoRoute(
              path: 'bookmarks',
              builder: placeholder,
              routes: <RouteBase>[GoRoute(path: ':id', builder: placeholder)],
            ),
          ],
        ),
      ],
    );
  }
}

/// A viewport tall enough that a full screen fits without scrolling.
///
/// The default 800x600 test surface hides most of every page behind a scroll,
/// which turns "does this row exist" assertions into scroll choreography.
const Size tallSurface = Size(1000, 2400);

/// Pumps [child] inside a [TestScope] and settles the frame.
Future<TestScope> pumpInScope(
  WidgetTester tester,
  Widget child, {
  TestScope? scope,
  Locale? locale,
  List<NavigatorObserver>? observers,
  Size surfaceSize = tallSurface,
}) async {
  tester.view
    ..physicalSize = surfaceSize
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final resolved = scope ?? TestScope();
  await tester.pumpWidget(
    resolved.wrap(child, locale: locale, observers: observers),
  );
  await tester.pumpAndSettle();
  return resolved;
}

/// Pumps a bare widget with theme and localisations but no providers.
///
/// For leaf UI components that must not reach for app state.
///
/// Pass `settle: false` when the widget runs a continuous animation (a
/// progress spinner, for example) — `pumpAndSettle` never returns for those.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale? locale,
  bool settle = true,
  bool wrapInScaffold = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: wrapInScaffold ? Scaffold(body: child) : child,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Records the routes a test pushes, so navigation can be asserted without a
/// real destination screen.
class RouteRecorder extends NavigatorObserver {
  final List<String?> pushed = <String?>[];
  final List<String?> popped = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route.settings.name);
    super.didPop(route, previousRoute);
  }
}
