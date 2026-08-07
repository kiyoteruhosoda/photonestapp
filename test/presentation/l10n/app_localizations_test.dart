import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_ja.dart';

/// One accessor per string on [AppLocalizations].
///
/// Reading every getter is the point: a translation file that forgets an
/// override, or returns an empty string, fails here rather than shipping a
/// blank label. `_keyNames` runs in lockstep so a failure names the string.
final List<String Function(AppLocalizations)> _accessors =
    <String Function(AppLocalizations)>[
      (l) => l.appName,
      (l) => l.navHome,
      (l) => l.navSearch,
      (l) => l.navSettings,
      (l) => l.drawerClose,
      (l) => l.drawerAbout,
      (l) => l.drawerLicenses,
      (l) => l.drawerDebug,
      (l) => l.drawerLogs,
      (l) => l.drawerBookmarks,
      (l) => l.drawerDeepLink,
      (l) => l.homeWelcomeTitle,
      (l) => l.homeCardBody,
      (l) => l.homeComponentsTitle,
      (l) => l.homePrimaryButton,
      (l) => l.homeSecondaryButton,
      (l) => l.homeTextFieldLabel,
      (l) => l.homeTextFieldHint,
      (l) => l.homeListCardTitle,
      (l) => l.homeListCardSubtitle,
      (l) => l.homeListCardItem2,
      (l) => l.searchFieldLabel,
      (l) => l.searchFieldHint,
      (l) => l.searchEmptyMessage,
      (l) => l.settingsTitle,
      (l) => l.settingsTheme,
      (l) => l.settingsThemeSystem,
      (l) => l.settingsThemeLight,
      (l) => l.settingsThemeDark,
      (l) => l.settingsLanguage,
      (l) => l.settingsLanguageSystem,
      (l) => l.settingsLanguageEnglish,
      (l) => l.settingsLanguageJapanese,
      (l) => l.settingsAbout,
      (l) => l.settingsLicenses,
      (l) => l.settingsDebug,
      (l) => l.settingsLogs,
      (l) => l.settingsBookmarks,
      (l) => l.settingsDeepLink,
      (l) => l.footerAbout,
      (l) => l.footerLicenses,
      (l) => l.aboutTitle,
      (l) => l.aboutVersion,
      (l) => l.aboutBuildNumber,
      (l) => l.aboutGitCommit,
      (l) => l.aboutFlutterVersion,
      (l) => l.aboutDartVersion,
      (l) => l.aboutPlatform,
      (l) => l.aboutPlatformValue,
      (l) => l.aboutDebugUnlocked,
      (l) => l.aboutDebugAlreadyOn,
      (l) => l.debugTitle,
      (l) => l.debugWarning,
      (l) => l.debugAppInfoSection,
      (l) => l.debugThemeSection,
      (l) => l.debugThemeMode,
      (l) => l.debugThemeModeDark,
      (l) => l.debugThemeModeLight,
      (l) => l.debugPrimaryColor,
      (l) => l.debugSurfaceColor,
      (l) => l.debugActionsSection,
      (l) => l.debugClearLogs,
      (l) => l.debugClearLogsSuccess,
      (l) => l.debugClearCache,
      (l) => l.debugClearCacheSuccess,
      (l) => l.debugTestCrash,
      (l) => l.debugTestCrashTitle,
      (l) => l.debugTestCrashBody,
      (l) => l.debugCopyAll,
      (l) => l.debugCopiedToClipboard,
      (l) => l.debugCancel,
      (l) => l.debugCrash,
      (l) => l.debugAppName,
      (l) => l.debugVersion,
      (l) => l.debugBuildNumber,
      (l) => l.debugGitCommit,
      (l) => l.debugFlutterVersion,
      (l) => l.debugDartVersion,
      (l) => l.debugPlatform,
      (l) => l.debugDesignSystem,
      (l) => l.debugBuildDate,
      (l) => l.debugIsDebugBuild,
      (l) => l.logsTitle,
      (l) => l.logsAll,
      (l) => l.logsVerbose,
      (l) => l.logsDebug,
      (l) => l.logsInfo,
      (l) => l.logsWarning,
      (l) => l.logsError,
      (l) => l.logsClear,
      (l) => l.logsClearConfirmTitle,
      (l) => l.logsClearConfirmBody,
      (l) => l.logsClearSuccess,
      (l) => l.logsDownload,
      (l) => l.logsDownloadSuccess,
      (l) => l.logsDownloadError,
      (l) => l.logsEmpty,
      (l) => l.logsCancel,
      (l) => l.logsConfirm,
      (l) => l.logsCopied,
      (l) => l.settingsDeveloper,
      (l) => l.settingsDebugMode,
      (l) => l.settingsDebugModeSubtitle,
      (l) => l.settingsLogLevel,
      (l) => l.logLevelVerbose,
      (l) => l.logLevelDebug,
      (l) => l.logLevelInfo,
      (l) => l.logLevelWarning,
      (l) => l.logLevelError,
      (l) => l.bookmarksTitle,
      (l) => l.bookmarksEmpty,
      (l) => l.bookmarksEmptyHint,
      (l) => l.bookmarksAdd,
      (l) => l.bookmarksAddTitle,
      (l) => l.bookmarksTitleLabel,
      (l) => l.bookmarksTitleHint,
      (l) => l.bookmarksUrlLabel,
      (l) => l.bookmarksUrlHint,
      (l) => l.bookmarksSave,
      (l) => l.bookmarksCancel,
      (l) => l.bookmarksInvalidInput,
      (l) => l.bookmarksSaved,
      (l) => l.bookmarksRemoved,
      (l) => l.bookmarkDetailTitle,
      (l) => l.bookmarkNotFound,
      (l) => l.bookmarkNotFoundHint,
      (l) => l.bookmarkOpen,
      (l) => l.bookmarkOpenFailed,
      (l) => l.bookmarkRemove,
      (l) => l.bookmarkRemoveConfirmTitle,
      (l) => l.bookmarkRemoveConfirmBody,
      (l) => l.bookmarkUrlLabel,
      (l) => l.bookmarkCreatedAtLabel,
      (l) => l.bookmarkDeepLinkLabel,
      (l) => l.deepLinkTitle,
      (l) => l.deepLinkIntro,
      (l) => l.deepLinkOpenedWith,
      (l) => l.deepLinkNoParameters,
      (l) => l.deepLinkParameters,
      (l) => l.deepLinkVerifiedSection,
      (l) => l.deepLinkCustomSchemeSection,
      (l) => l.deepLinkTrySection,
      (l) => l.deepLinkTryHint,
      (l) => l.deepLinkCopy,
      (l) => l.deepLinkCopied,
      (l) => l.licensesTitle,
      (l) => l.licensesDetails,
      (l) => l.commonRetry,
      (l) => l.commonMenu,
      (l) => l.commonNotifications,
      (l) => l.commonNotFound,
      (l) => l.commonPageNotFound,
      (l) => l.commonLoading,
      (l) => l.commonError,
      (l) => l.commonEmpty,
    ];

const List<String> _keyNames = <String>[
  'appName',
  'navHome',
  'navSearch',
  'navSettings',
  'drawerClose',
  'drawerAbout',
  'drawerLicenses',
  'drawerDebug',
  'drawerLogs',
  'drawerBookmarks',
  'drawerDeepLink',
  'homeWelcomeTitle',
  'homeCardBody',
  'homeComponentsTitle',
  'homePrimaryButton',
  'homeSecondaryButton',
  'homeTextFieldLabel',
  'homeTextFieldHint',
  'homeListCardTitle',
  'homeListCardSubtitle',
  'homeListCardItem2',
  'searchFieldLabel',
  'searchFieldHint',
  'searchEmptyMessage',
  'settingsTitle',
  'settingsTheme',
  'settingsThemeSystem',
  'settingsThemeLight',
  'settingsThemeDark',
  'settingsLanguage',
  'settingsLanguageSystem',
  'settingsLanguageEnglish',
  'settingsLanguageJapanese',
  'settingsAbout',
  'settingsLicenses',
  'settingsDebug',
  'settingsLogs',
  'settingsBookmarks',
  'settingsDeepLink',
  'footerAbout',
  'footerLicenses',
  'aboutTitle',
  'aboutVersion',
  'aboutBuildNumber',
  'aboutGitCommit',
  'aboutFlutterVersion',
  'aboutDartVersion',
  'aboutPlatform',
  'aboutPlatformValue',
  'aboutDebugUnlocked',
  'aboutDebugAlreadyOn',
  'debugTitle',
  'debugWarning',
  'debugAppInfoSection',
  'debugThemeSection',
  'debugThemeMode',
  'debugThemeModeDark',
  'debugThemeModeLight',
  'debugPrimaryColor',
  'debugSurfaceColor',
  'debugActionsSection',
  'debugClearLogs',
  'debugClearLogsSuccess',
  'debugClearCache',
  'debugClearCacheSuccess',
  'debugTestCrash',
  'debugTestCrashTitle',
  'debugTestCrashBody',
  'debugCopyAll',
  'debugCopiedToClipboard',
  'debugCancel',
  'debugCrash',
  'debugAppName',
  'debugVersion',
  'debugBuildNumber',
  'debugGitCommit',
  'debugFlutterVersion',
  'debugDartVersion',
  'debugPlatform',
  'debugDesignSystem',
  'debugBuildDate',
  'debugIsDebugBuild',
  'logsTitle',
  'logsAll',
  'logsVerbose',
  'logsDebug',
  'logsInfo',
  'logsWarning',
  'logsError',
  'logsClear',
  'logsClearConfirmTitle',
  'logsClearConfirmBody',
  'logsClearSuccess',
  'logsDownload',
  'logsDownloadSuccess',
  'logsDownloadError',
  'logsEmpty',
  'logsCancel',
  'logsConfirm',
  'logsCopied',
  'settingsDeveloper',
  'settingsDebugMode',
  'settingsDebugModeSubtitle',
  'settingsLogLevel',
  'logLevelVerbose',
  'logLevelDebug',
  'logLevelInfo',
  'logLevelWarning',
  'logLevelError',
  'bookmarksTitle',
  'bookmarksEmpty',
  'bookmarksEmptyHint',
  'bookmarksAdd',
  'bookmarksAddTitle',
  'bookmarksTitleLabel',
  'bookmarksTitleHint',
  'bookmarksUrlLabel',
  'bookmarksUrlHint',
  'bookmarksSave',
  'bookmarksCancel',
  'bookmarksInvalidInput',
  'bookmarksSaved',
  'bookmarksRemoved',
  'bookmarkDetailTitle',
  'bookmarkNotFound',
  'bookmarkNotFoundHint',
  'bookmarkOpen',
  'bookmarkOpenFailed',
  'bookmarkRemove',
  'bookmarkRemoveConfirmTitle',
  'bookmarkRemoveConfirmBody',
  'bookmarkUrlLabel',
  'bookmarkCreatedAtLabel',
  'bookmarkDeepLinkLabel',
  'deepLinkTitle',
  'deepLinkIntro',
  'deepLinkOpenedWith',
  'deepLinkNoParameters',
  'deepLinkParameters',
  'deepLinkVerifiedSection',
  'deepLinkCustomSchemeSection',
  'deepLinkTrySection',
  'deepLinkTryHint',
  'deepLinkCopy',
  'deepLinkCopied',
  'licensesTitle',
  'licensesDetails',
  'commonRetry',
  'commonMenu',
  'commonNotifications',
  'commonNotFound',
  'commonPageNotFound',
  'commonLoading',
  'commonError',
  'commonEmpty',
];

void main() {
  const locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'ja': AppLocalizationsJa(),
  };

  test('the accessor list and the key-name list stay in step', () {
    expect(_accessors, hasLength(_keyNames.length));
  });

  for (final entry in locales.entries) {
    group('AppLocalizations (${entry.key})', () {
      test('every string is non-empty', () {
        final blank = <String>[];
        for (var i = 0; i < _accessors.length; i++) {
          if (_accessors[i](entry.value).trim().isEmpty) {
            blank.add(_keyNames[i]);
          }
        }
        expect(blank, isEmpty, reason: 'blank strings in "${entry.key}"');
      });

      test('strings do not leak a placeholder marker', () {
        final suspicious = <String>[];
        for (var i = 0; i < _accessors.length; i++) {
          final value = _accessors[i](entry.value);
          if (value.contains('TODO') || value.contains(r'${')) {
            suspicious.add(_keyNames[i]);
          }
        }
        expect(suspicious, isEmpty);
      });
    });
  }

  test('Japanese differs from English for user-facing copy', () {
    // A handful of strings are intentionally identical across locales
    // (product names, hex-ish values). Everything else should be translated.
    var translated = 0;
    for (var i = 0; i < _accessors.length; i++) {
      if (_accessors[i](locales['en']!) != _accessors[i](locales['ja']!)) {
        translated++;
      }
    }
    expect(translated, greaterThan(_accessors.length ~/ 2));
  });

  group('supportedLocales', () {
    test('lists exactly the locales that have a translation', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(locales.keys),
      );
      expect(AppLocalizations.supportedLocales, hasLength(locales.length));
    });
  });

  group('delegate', () {
    const delegate = AppLocalizations.delegate;

    test('supports every advertised locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(delegate.isSupported(locale), isTrue);
      }
    });

    test('supports a locale with a country code', () {
      expect(delegate.isSupported(const Locale('ja', 'JP')), isTrue);
    });

    test('rejects an unsupported locale', () {
      expect(delegate.isSupported(const Locale('fr')), isFalse);
    });

    test('loads the Japanese translation for "ja"', () async {
      expect(
        await delegate.load(const Locale('ja')),
        isA<AppLocalizationsJa>(),
      );
    });

    test('falls back to English for anything else', () async {
      expect(
        await delegate.load(const Locale('fr')),
        isA<AppLocalizationsEn>(),
      );
    });

    test('never asks to be reloaded', () {
      expect(delegate.shouldReload(delegate), isFalse);
    });
  });

  group('AppLocalizations.of', () {
    testWidgets('returns the injected localisation', (tester) async {
      late AppLocalizations resolved;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('ja'),
          delegates: const [
            AppLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              resolved = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, isA<AppLocalizationsJa>());
    });

    testWidgets('falls back to English when none is injected', (tester) async {
      late AppLocalizations resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              resolved = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, isA<AppLocalizationsEn>());
    });
  });
}
