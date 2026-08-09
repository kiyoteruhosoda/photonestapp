import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photonest/app/bootstrap/app_router.dart';
import 'package:photonest/app/di/service_locator.dart';
import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/services/auto_upload_coordinator.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/providers/session_providers.dart';
import 'package:photonest/presentation/providers/settings_providers.dart';
import 'package:photonest/presentation/providers/upload_providers.dart';
import 'package:photonest/presentation/theme/app_theme.dart';

/// Root widget.
///
/// A [ConsumerStatefulWidget]: theme, language, and session all live in
/// Riverpod, and this is where they meet the framework — `MaterialApp`
/// settings and the router's auth guard.
///
/// Uses `MaterialApp.router`: the Router API is what lets the platform push a
/// location into a running app, which is what makes an incoming App Link an
/// ordinary navigation instead of a special case.
class AppWidget extends ConsumerStatefulWidget {
  const AppWidget({super.key});

  @override
  ConsumerState<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends ConsumerState<AppWidget>
    with WidgetsBindingObserver {
  late final AppLogger _logger;
  late final AutoUploadCoordinator _autoUploadCoordinator;
  final RouterRefreshBridge _routerRefresh = RouterRefreshBridge();

  /// Built once: a router recreated on every rebuild would drop the
  /// navigation stack, including the screen a deep link just opened.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _logger = sl<AppLogger>();
    _router = AppRouter.create(
      logger: _logger,
      refreshListenable: _routerRefresh,
    );
    // The guard reads the session provider; this listener is what re-runs
    // it when the session changes (login, logout, forced expiry).
    ref.listenManual<bool>(
      sessionProvider.select((state) => state.isAuthenticated),
      (_, _) => _routerRefresh.poke(),
    );
    // Watches the photo library for the whole app run. Each sync pass
    // re-checks the preconditions itself, so it is safe to start
    // unconditionally — signed out or disabled just means cheap no-ops.
    _autoUploadCoordinator = sl<AutoUploadCoordinator>()..start();
    WidgetsBinding.instance.addObserver(this);
    _logger.info('[App] AppWidget initialised');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_autoUploadCoordinator.stop());
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.debug('[App] Lifecycle → ${state.name}');
    // Photos taken while the app was backgrounded produce no change event
    // on every platform, so returning to the foreground is a sync trigger.
    if (state == AppLifecycleState.resumed) {
      unawaited(_autoUploadCoordinator.triggerSync());
      // The background upload engine records its failures in its own
      // isolate, so its writes never reach this isolate's change stream.
      // Coming back to the foreground is when a pass is most likely to have
      // happened unseen, so the list is re-read rather than left stale.
      unawaited(ref.read(uploadFailuresProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: localeOf(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
