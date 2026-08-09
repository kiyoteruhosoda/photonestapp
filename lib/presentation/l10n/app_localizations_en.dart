import 'package:photonest/presentation/l10n/app_localizations.dart';

/// English localisations.
class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  // ─── Navigation ───────────────────────────────────────────────────────
  @override
  String get appName => 'PhotoNest';
  @override
  String get navHome => 'Home';
  @override
  String get navSettings => 'Settings';
  @override
  String get navAlbums => 'Albums';
  @override
  String get navPhotos => 'Photos';
  @override
  String get navUpload => 'Upload';

  // ─── Login ────────────────────────────────────────────────────────────
  @override
  String get loginTitle => 'Sign in';
  @override
  String get loginSubtitle => 'Sign in to your PhotoNest server';
  @override
  String get loginServerLabel => 'Server URL';
  @override
  String get loginServerHint => 'https://photos.example.com';
  @override
  String get loginEmailLabel => 'E-mail';
  @override
  String get loginEmailHint => 'you@example.com';
  @override
  String get loginPasswordLabel => 'Password';
  @override
  String get loginSubmit => 'Sign in';
  @override
  String get loginErrorInvalidInput =>
      'Check the server URL, e-mail, and password.';
  @override
  String get loginErrorInvalidCredentials =>
      'The e-mail or password is incorrect.';
  @override
  String get loginErrorNetwork =>
      'Could not reach the server. Check the URL and your connection.';

  // ─── Albums ───────────────────────────────────────────────────────────
  @override
  String get albumsTitle => 'Albums';
  @override
  String get albumsEmpty => 'No albums yet';
  @override
  String get albumsEmptyHint => 'Albums you create on the server appear here.';
  @override
  String albumsMediaCount(int count) => count == 1 ? '1 item' : '$count items';
  @override
  String get albumNotFound => 'Album not found';
  @override
  String get albumNotFoundHint => 'It may have been deleted on the server.';
  @override
  String get albumEmpty => 'This album has no photos yet.';

  @override
  String get albumLoadMoreRetry => 'Could not load more items. Tap to retry.';

  // ─── Photos (library timeline) ────────────────────────────────────────

  @override
  String get photosEmpty => 'No photos on the server yet.';
  @override
  String get photosUndatedSection => 'No date';
  @override
  String get photosLoadMoreRetry => 'Could not load more photos. Retry';

  @override
  String get mediaVideoLabel => 'Video';
  @override
  String mediaViewerPosition(int position, int total) => '$position / $total';
  @override
  String get mediaShowOriginal => 'Show the original';
  @override
  String get mediaOriginalUnavailable => 'Could not load the original.';
  @override
  String get mediaSaveToDevice => 'Save to this device';
  @override
  String get mediaSaveDone => 'Saved to your device.';
  @override
  String get mediaSaveNoAccess => 'Photo library access is required to save.';
  @override
  String get mediaSaveDownloadFailed => 'Could not download the original.';
  @override
  String get mediaSaveWriteFailed => 'Could not save to your device.';
  @override
  String get mediaAddFavorite => 'Add to favorites';
  @override
  String get mediaRemoveFavorite => 'Remove from favorites';
  @override
  String get mediaFavoriteFailed => 'Could not change the favorite mark.';
  @override
  String get mediaMoveToTrash => 'Move to trash';
  @override
  String get mediaMoveToTrashConfirm =>
      'Move this to the trash? You can restore it until the server clears it.';
  @override
  String get mediaMovedToTrash => 'Moved to the trash.';
  @override
  String get mediaTrashFailed => 'Could not move this to the trash.';

  @override
  String get mediaTagsTitle => 'Tags';
  @override
  String get mediaTagsSave => 'Save';
  @override
  String get mediaTagsNoneOnMedia => 'No tags on this item yet.';
  @override
  String get mediaTagsSearchLabel => 'Search tags';
  @override
  String get mediaTagsNoMatches => 'No tags matched.';
  @override
  String get tagAttributeThing => 'Thing';
  @override
  String get tagAttributePerson => 'Person';
  @override
  String get tagAttributePlace => 'Place';
  @override
  String get tagAttributeEvent => 'Event';
  @override
  String get tagAttributeScene => 'Scene';
  @override
  String get tagAttributeActivity => 'Activity';
  @override
  String get tagAttributeSource => 'Source';
  @override
  String get tagAttributeOthers => 'Other';

  @override
  String get videoNotReady =>
      'The video is still being prepared on the server. Try again later.';

  @override
  String get videoUnavailable => 'This video cannot be played.';

  // ─── Trash ────────────────────────────────────────────────────────────
  @override
  String get trashTitle => 'Trash';
  @override
  String get trashEmpty => 'The trash is empty';
  @override
  String get trashRestore => 'Restore';
  @override
  String get trashRestored => 'Restored.';
  @override
  String get trashRestoreFailed =>
      'Could not restore this. The file may already have been cleared.';

  // ─── Upload ───────────────────────────────────────────────────────────
  @override
  String get uploadAutoTitle => 'Auto-upload new photos';
  @override
  String get uploadAutoSubtitle =>
      'Photos you take from now on are uploaded automatically.';
  @override
  String get uploadAutoDenied =>
      'Photo library access is required for auto-upload.';
  @override
  String get uploadAutoUnmeteredTitle => 'Only over Wi-Fi';
  @override
  String get uploadAutoUnmeteredSubtitle =>
      'Wait for Wi-Fi instead of uploading over mobile data.';
  @override
  String get uploadAutoAlbumsTitle => 'What gets backed up';
  @override
  String get uploadAutoAlbumsAll => 'Everything on this device';
  @override
  String uploadAutoAlbumsCount(int count) =>
      count == 1 ? '1 album' : '$count albums';
  @override
  String get uploadAutoAlbumsDialogTitle => 'What gets backed up';
  @override
  String get uploadAutoAlbumsAllOption => 'Everything on this device';
  @override
  String get uploadAutoAlbumsAllOptionSubtitle =>
      'Includes screenshots, saved images, and videos.';
  @override
  String get uploadAutoAlbumsEmpty => 'No albums found on this device.';
  @override
  String get uploadAutoAlbumsPickOne => 'Choose at least one album.';
  @override
  String uploadAutoAlbumsItemCount(int count) =>
      count == 1 ? '1 item' : '$count items';
  @override
  String get uploadPermissionTitle => 'No photo access';
  @override
  String get uploadPermissionBody =>
      'Allow photo library access to upload your photos.';
  @override
  String get uploadPermissionRetry => 'Allow access';
  @override
  String get uploadEmpty => 'No photos found on this device.';
  @override
  String get uploadRecentSection => 'Recent photos';
  @override
  String uploadSelectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';
  @override
  String get uploadSubmit => 'Upload selected';
  @override
  String uploadDone(int count) =>
      count == 1 ? 'Uploaded 1 photo.' : 'Uploaded $count photos.';
  @override
  String uploadFailed(int count) => count == 1
      ? '1 photo could not be uploaded.'
      : '$count photos could not be uploaded.';
  @override
  String get uploadUploadedBadge => 'Uploaded';
  @override
  String uploadProgress(int completed, int total) =>
      'Uploading $completed of $total…';
  @override
  String get uploadCancel => 'Cancel';
  @override
  String get uploadCancelled => 'Upload cancelled.';
  @override
  String get uploadShowFailures => 'Details';
  @override
  String uploadFailureAttempts(int attempts) => '$attempts attempts';
  @override
  String get uploadFailureAutomatic => 'auto-upload';
  @override
  String get uploadFailureListTitle => 'Failed uploads';
  @override
  String get uploadFailureMissing => 'No longer in the device library.';
  @override
  String get uploadFailureUnsupported => 'This file type is not supported.';
  @override
  String get uploadFailureRejected => 'The server did not accept this photo.';

  // ─── Session / sign out ───────────────────────────────────────────────
  @override
  String get settingsSignOut => 'Sign out';
  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';
  @override
  String get settingsSignOutConfirmBody =>
      'Auto-upload stops until you sign in again.';
  @override
  String get settingsSignOutCancel => 'Cancel';
  @override
  String get settingsSignedInAs => 'Signed in as';

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
  String get drawerDeepLink => 'Deep Links';

  // ─── Media search ─────────────────────────────────────────────────────
  @override
  String get searchFieldLabel => 'Search';
  @override
  String get searchFieldHint => 'Filename, camera, caption or tag';
  @override
  String get searchNoResults => 'No photos match the current filters';
  @override
  String get searchClearFilters => 'Clear filters';
  @override
  String get searchFilterAll => 'All';
  @override
  String get searchFilterPhotos => 'Photos';
  @override
  String get searchFilterVideos => 'Videos';
  @override
  String get searchFilterFavorites => 'Favorites';

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

  // ─── Notifications ───────────────────────────────────────────────────
  @override
  String get notificationsTitle => 'Notifications';
  @override
  String get notificationsEmpty => 'No notifications yet';
  @override
  String get notificationsEmptyHint => 'Backup results appear here.';
  @override
  String get notificationBackupCompleted => 'Backup finished';
  @override
  String get notificationBackupHadFailures => 'Backup finished with errors';

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

  // ─── Common ──────────────────────────────────────────────────────────
  @override
  String get commonRetry => 'Retry';
  @override
  String get commonClose => 'Close';
  @override
  String get commonCancel => 'Cancel';
  @override
  String get commonSave => 'Save';
  @override
  String get commonErrorNetwork =>
      'Could not reach the server. Check your connection and try again.';
  @override
  String get commonErrorSessionExpired =>
      'Your session has expired. Please sign in again.';
  @override
  String get commonMenu => 'Menu';
  @override
  String get commonNotifications => 'Notifications';
  @override
  String get commonNotFound => '404 - Page not found';
  @override
  String get commonPageNotFound => 'Page Not Found';
  @override
  String get commonError => 'An error occurred';
}
