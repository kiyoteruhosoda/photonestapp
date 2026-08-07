import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_ja.dart';

/// Centralised, locale-aware string resources.
///
/// All user-visible strings must come from here — never hardcoded inline.
/// Access via [AppLocalizations.of] from within the widget tree:
/// ```dart
/// final l10n = AppLocalizations.of(context);
/// Text(l10n.navHome);
/// ```
///
/// App identity values that appear in UI (for example app name) are also
/// modelled here so locale changes are reflected consistently.
abstract class AppLocalizations {
  const AppLocalizations();

  /// Locales supported by the app.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// Delegate wired into `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Resolves the current [AppLocalizations] for [context]. Falls back to
  /// English if no localisation was injected — useful during tests.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizationsEn();
  }

  // ─── Navigation ───────────────────────────────────────────────────────
  String get appName;
  String get navHome;
  String get navSearch;
  String get navSettings;

  // ─── Drawer ───────────────────────────────────────────────────────────
  String get drawerClose;
  String get drawerAbout;
  String get drawerLicenses;
  String get drawerDebug;
  String get drawerLogs;
  String get drawerBookmarks;
  String get drawerDeepLink;

  // ─── Home tab ─────────────────────────────────────────────────────────
  String get homeWelcomeTitle;
  String get homeCardBody;
  String get homeComponentsTitle;
  String get homePrimaryButton;
  String get homeSecondaryButton;
  String get homeTextFieldLabel;
  String get homeTextFieldHint;
  String get homeListCardTitle;
  String get homeListCardSubtitle;
  String get homeListCardItem2;

  // ─── Search tab ───────────────────────────────────────────────────────
  String get searchFieldLabel;
  String get searchFieldHint;
  String get searchEmptyMessage;

  // ─── Settings tab ─────────────────────────────────────────────────────
  String get settingsTitle;
  String get settingsTheme;
  String get settingsThemeSystem;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsLanguage;
  String get settingsLanguageSystem;
  String get settingsLanguageEnglish;
  String get settingsLanguageJapanese;
  String get settingsAbout;
  String get settingsLicenses;
  String get settingsDebug;
  String get settingsLogs;
  String get settingsBookmarks;
  String get settingsDeepLink;

  // ─── Footer ───────────────────────────────────────────────────────────
  String get footerAbout;
  String get footerLicenses;

  // ─── About page ───────────────────────────────────────────────────────
  String get aboutTitle;
  String get aboutVersion;
  String get aboutBuildNumber;
  String get aboutGitCommit;
  String get aboutFlutterVersion;
  String get aboutDartVersion;
  String get aboutPlatform;
  String get aboutPlatformValue;
  String get aboutDebugUnlocked;
  String get aboutDebugAlreadyOn;

  // ─── Debug page ───────────────────────────────────────────────────────
  String get debugTitle;
  String get debugWarning;
  String get debugAppInfoSection;
  String get debugThemeSection;
  String get debugThemeMode;
  String get debugThemeModeDark;
  String get debugThemeModeLight;
  String get debugPrimaryColor;
  String get debugSurfaceColor;
  String get debugActionsSection;
  String get debugClearLogs;
  String get debugClearLogsSuccess;
  String get debugClearCache;
  String get debugClearCacheSuccess;
  String get debugTestCrash;
  String get debugTestCrashTitle;
  String get debugTestCrashBody;
  String get debugCopyAll;
  String get debugCopiedToClipboard;
  String get debugCancel;
  String get debugCrash;
  String get debugAppName;
  String get debugVersion;
  String get debugBuildNumber;
  String get debugGitCommit;
  String get debugFlutterVersion;
  String get debugDartVersion;
  String get debugPlatform;
  String get debugDesignSystem;
  String get debugBuildDate;
  String get debugIsDebugBuild;

  // ─── Logs page ────────────────────────────────────────────────────────
  String get logsTitle;
  String get logsAll;
  String get logsVerbose;
  String get logsDebug;
  String get logsInfo;
  String get logsWarning;
  String get logsError;
  String get logsClear;
  String get logsClearConfirmTitle;
  String get logsClearConfirmBody;
  String get logsClearSuccess;
  String get logsDownload;
  String get logsDownloadSuccess;
  String get logsDownloadError;
  String get logsEmpty;
  String get logsCancel;
  String get logsConfirm;
  String get logsCopied;

  // ─── Developer settings ───────────────────────────────────────────────
  String get settingsDeveloper;
  String get settingsDebugMode;
  String get settingsDebugModeSubtitle;
  String get settingsLogLevel;
  String get logLevelVerbose;
  String get logLevelDebug;
  String get logLevelInfo;
  String get logLevelWarning;
  String get logLevelError;

  // ─── Bookmarks (sample feature) ──────────────────────────────────────
  String get bookmarksTitle;
  String get bookmarksEmpty;
  String get bookmarksEmptyHint;
  String get bookmarksAdd;
  String get bookmarksAddTitle;
  String get bookmarksTitleLabel;
  String get bookmarksTitleHint;
  String get bookmarksUrlLabel;
  String get bookmarksUrlHint;
  String get bookmarksSave;
  String get bookmarksCancel;
  String get bookmarksInvalidInput;
  String get bookmarksSaved;
  String get bookmarksRemoved;
  String get bookmarkDetailTitle;
  String get bookmarkNotFound;
  String get bookmarkNotFoundHint;
  String get bookmarkOpen;
  String get bookmarkOpenFailed;
  String get bookmarkRemove;
  String get bookmarkRemoveConfirmTitle;
  String get bookmarkRemoveConfirmBody;
  String get bookmarkUrlLabel;
  String get bookmarkCreatedAtLabel;
  String get bookmarkDeepLinkLabel;

  // ─── Deep links (App Links) ──────────────────────────────────────────
  String get deepLinkTitle;
  String get deepLinkIntro;
  String get deepLinkOpenedWith;
  String get deepLinkNoParameters;
  String get deepLinkParameters;
  String get deepLinkVerifiedSection;
  String get deepLinkCustomSchemeSection;
  String get deepLinkTrySection;
  String get deepLinkTryHint;
  String get deepLinkCopy;
  String get deepLinkCopied;

  // ─── Licenses page ───────────────────────────────────────────────────
  String get licensesTitle;
  String get licensesDetails;

  // ─── Common ──────────────────────────────────────────────────────────
  String get commonRetry;
  String get commonMenu;
  String get commonNotifications;
  String get commonNotFound;
  String get commonPageNotFound;
  String get commonLoading;
  String get commonError;
  String get commonEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(switch (locale.languageCode) {
      'ja' => const AppLocalizationsJa(),
      _ => const AppLocalizationsEn(),
    });
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
