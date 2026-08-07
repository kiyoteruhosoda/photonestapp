import 'package:flutterbase/presentation/l10n/app_localizations.dart';

/// English localisations.
class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  // ─── Navigation ───────────────────────────────────────────────────────
  @override
  String get appName => 'FlutterBase';
  @override
  String get navHome => 'Home';
  @override
  String get navSearch => 'Search';
  @override
  String get navSettings => 'Settings';

  // ─── Drawer ───────────────────────────────────────────────────────────
  @override
  String get drawerClose => 'Close';
  @override
  String get drawerAbout => 'About';
  @override
  String get drawerLicenses => 'Licenses';
  @override
  String get drawerDebug => 'Debug Info';
  @override
  String get drawerLogs => 'Logs';
  @override
  String get drawerBookmarks => 'Bookmarks';
  @override
  String get drawerDeepLink => 'Deep Links';

  // ─── Home tab ─────────────────────────────────────────────────────────
  @override
  String get homeWelcomeTitle => 'Welcome';
  @override
  String get homeCardBody =>
      'This app is built following the Digital Agency Design System (DADS). '
      'It provides a consistent UI based on color tokens, typography, '
      'and spacing.';
  @override
  String get homeComponentsTitle => 'Components';
  @override
  String get homePrimaryButton => 'Primary Button';
  @override
  String get homeSecondaryButton => 'Secondary Button';
  @override
  String get homeTextFieldLabel => 'Text Input';
  @override
  String get homeTextFieldHint => 'Enter text here';
  @override
  String get homeListCardTitle => 'List Card';
  @override
  String get homeListCardSubtitle => 'Subtitle text';
  @override
  String get homeListCardItem2 => 'Item 2';

  // ─── Search tab ───────────────────────────────────────────────────────
  @override
  String get searchFieldLabel => 'Search';
  @override
  String get searchFieldHint => 'Enter keyword';
  @override
  String get searchEmptyMessage => 'Enter a keyword to search';

  // ─── Settings tab ─────────────────────────────────────────────────────
  @override
  String get settingsTitle => 'Settings';
  @override
  String get settingsTheme => 'Theme';
  @override
  String get settingsThemeSystem => 'System default';
  @override
  String get settingsThemeLight => 'Light';
  @override
  String get settingsThemeDark => 'Dark';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsLanguageSystem => 'System default';
  @override
  String get settingsLanguageEnglish => 'English';
  @override
  String get settingsLanguageJapanese => 'Japanese';
  @override
  String get settingsAbout => 'About';
  @override
  String get settingsLicenses => 'Licenses';
  @override
  String get settingsDebug => 'Debug Info';
  @override
  String get settingsLogs => 'Logs';
  @override
  String get settingsBookmarks => 'Bookmarks';
  @override
  String get settingsDeepLink => 'Deep Links';

  // ─── Footer ───────────────────────────────────────────────────────────
  @override
  String get footerAbout => 'About';
  @override
  String get footerLicenses => 'Licenses';

  // ─── About page ───────────────────────────────────────────────────────
  @override
  String get aboutTitle => 'About';
  @override
  String get aboutVersion => 'Version';
  @override
  String get aboutBuildNumber => 'Build Number';
  @override
  String get aboutGitCommit => 'Git Commit';
  @override
  String get aboutFlutterVersion => 'Flutter Version';
  @override
  String get aboutDartVersion => 'Dart Version';
  @override
  String get aboutPlatform => 'Platform';
  @override
  String get aboutPlatformValue => 'Android / iOS';
  @override
  String get aboutDebugUnlocked => 'Debug mode enabled';
  @override
  String get aboutDebugAlreadyOn => 'Debug mode is already on';

  // ─── Debug page ───────────────────────────────────────────────────────
  @override
  String get debugTitle => 'Debug Info';
  @override
  String get debugWarning =>
      'This page is for debug purposes only. Do not display in release builds.';
  @override
  String get debugAppInfoSection => 'App Info';
  @override
  String get debugThemeSection => 'Theme Info';
  @override
  String get debugThemeMode => 'Theme Mode';
  @override
  String get debugThemeModeDark => 'Dark Mode';
  @override
  String get debugThemeModeLight => 'Light Mode';
  @override
  String get debugPrimaryColor => 'Primary Color';
  @override
  String get debugSurfaceColor => 'Surface Color';
  @override
  String get debugActionsSection => 'Debug Actions';
  @override
  String get debugClearLogs => 'Clear Logs';
  @override
  String get debugClearLogsSuccess => 'Logs cleared';
  @override
  String get debugClearCache => 'Clear Cache';
  @override
  String get debugClearCacheSuccess => 'Cache cleared';
  @override
  String get debugTestCrash => 'Test Crash';
  @override
  String get debugTestCrashTitle => 'Test Crash';
  @override
  String get debugTestCrashBody => 'Crash the app for testing purposes?';
  @override
  String get debugCopyAll => 'Copy All';
  @override
  String get debugCopiedToClipboard => 'Copied to clipboard';
  @override
  String get debugCancel => 'Cancel';
  @override
  String get debugCrash => 'Crash';
  @override
  String get debugAppName => 'App Name';
  @override
  String get debugVersion => 'Version';
  @override
  String get debugBuildNumber => 'Build Number';
  @override
  String get debugGitCommit => 'Git Commit';
  @override
  String get debugFlutterVersion => 'Flutter Version';
  @override
  String get debugDartVersion => 'Dart Version';
  @override
  String get debugPlatform => 'Platform';
  @override
  String get debugDesignSystem => 'Design System';
  @override
  String get debugBuildDate => 'Build Date';
  @override
  String get debugIsDebugBuild => 'Debug Build';

  // ─── Logs page ────────────────────────────────────────────────────────
  @override
  String get logsTitle => 'Logs';
  @override
  String get logsAll => 'All';
  @override
  String get logsVerbose => 'Verbose';
  @override
  String get logsDebug => 'Debug';
  @override
  String get logsInfo => 'Info';
  @override
  String get logsWarning => 'Warning';
  @override
  String get logsError => 'Error';
  @override
  String get logsClear => 'Clear';
  @override
  String get logsClearConfirmTitle => 'Clear Logs';
  @override
  String get logsClearConfirmBody => 'Delete all log entries from memory?';
  @override
  String get logsClearSuccess => 'Logs cleared';
  @override
  String get logsDownload => 'Export';
  @override
  String get logsDownloadSuccess => 'Logs saved to file';
  @override
  String get logsDownloadError => 'Failed to save logs';
  @override
  String get logsEmpty => 'No log entries';
  @override
  String get logsCancel => 'Cancel';
  @override
  String get logsConfirm => 'Clear';
  @override
  String get logsCopied => 'Log entry copied';

  // ─── Developer settings ───────────────────────────────────────────────
  @override
  String get settingsDeveloper => 'Developer';
  @override
  String get settingsDebugMode => 'Debug Mode';
  @override
  String get settingsDebugModeSubtitle => 'Show Logs and Debug Info menu items';
  @override
  String get settingsLogLevel => 'Log Level';
  @override
  String get logLevelVerbose => 'Verbose';
  @override
  String get logLevelDebug => 'Debug';
  @override
  String get logLevelInfo => 'Info';
  @override
  String get logLevelWarning => 'Warning';
  @override
  String get logLevelError => 'Error';

  // ─── Bookmarks (sample feature) ──────────────────────────────────────
  @override
  String get bookmarksTitle => 'Bookmarks';
  @override
  String get bookmarksEmpty => 'No bookmarks yet';
  @override
  String get bookmarksEmptyHint =>
      'Saved links are stored in SQLite on this device.';
  @override
  String get bookmarksAdd => 'Add bookmark';
  @override
  String get bookmarksAddTitle => 'New bookmark';
  @override
  String get bookmarksTitleLabel => 'Title';
  @override
  String get bookmarksTitleHint => 'Flutter documentation';
  @override
  String get bookmarksUrlLabel => 'URL';
  @override
  String get bookmarksUrlHint => 'https://docs.flutter.dev';
  @override
  String get bookmarksSave => 'Save';
  @override
  String get bookmarksCancel => 'Cancel';
  @override
  String get bookmarksInvalidInput => 'Enter a title and an http/https URL.';
  @override
  String get bookmarksSaved => 'Bookmark saved';
  @override
  String get bookmarksRemoved => 'Bookmark removed';
  @override
  String get bookmarkDetailTitle => 'Bookmark';
  @override
  String get bookmarkNotFound => 'Bookmark not found';
  @override
  String get bookmarkNotFoundHint =>
      'It may have been deleted, or the link points at another device.';
  @override
  String get bookmarkOpen => 'Open link';
  @override
  String get bookmarkOpenFailed => 'No app can open this link';
  @override
  String get bookmarkRemove => 'Delete';
  @override
  String get bookmarkRemoveConfirmTitle => 'Delete bookmark';
  @override
  String get bookmarkRemoveConfirmBody =>
      'Remove this bookmark from this device?';
  @override
  String get bookmarkUrlLabel => 'URL';
  @override
  String get bookmarkCreatedAtLabel => 'Saved at';
  @override
  String get bookmarkDeepLinkLabel => 'Deep link';

  // ─── Deep links (App Links) ──────────────────────────────────────────
  @override
  String get deepLinkTitle => 'Deep Links';
  @override
  String get deepLinkIntro =>
      'Android App Links open a verified https URL straight in this app. '
      'The router matches the link path against the same routes the in-app '
      'navigation uses.';
  @override
  String get deepLinkOpenedWith => 'Opened with';
  @override
  String get deepLinkNoParameters => 'No query parameters';
  @override
  String get deepLinkParameters => 'Query parameters';
  @override
  String get deepLinkVerifiedSection => 'Verified App Link';
  @override
  String get deepLinkCustomSchemeSection => 'Custom scheme (unverified)';
  @override
  String get deepLinkTrySection => 'Try it';
  @override
  String get deepLinkTryHint =>
      'Run this with the app installed to open it from outside.';
  @override
  String get deepLinkCopy => 'Copy';
  @override
  String get deepLinkCopied => 'Copied to clipboard';

  // ─── Licenses page ───────────────────────────────────────────────────
  @override
  String get licensesTitle => 'Licenses';
  @override
  String get licensesDetails =>
      'Please refer to the package license file for details.';

  // ─── Common ──────────────────────────────────────────────────────────
  @override
  String get commonRetry => 'Retry';
  @override
  String get commonMenu => 'Menu';
  @override
  String get commonNotifications => 'Notifications';
  @override
  String get commonNotFound => '404 - Page not found';
  @override
  String get commonPageNotFound => 'Page Not Found';
  @override
  String get commonLoading => 'Loading...';
  @override
  String get commonError => 'An error occurred';
  @override
  String get commonEmpty => 'No data';
}
