import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/albums/albums_tab.dart';
import 'package:flutterbase/presentation/pages/upload/upload_tab.dart';
import 'package:flutterbase/presentation/providers/session_providers.dart';
import 'package:flutterbase/presentation/providers/settings_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';
import 'package:go_router/go_router.dart';

/// Main screen with bottom navigation.
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <_TabItem>[
      _TabItem(
        label: l10n.navAlbums,
        icon: Icons.photo_album_outlined,
        selectedIcon: Icons.photo_album,
      ),
      _TabItem(
        label: l10n.navUpload,
        icon: Icons.cloud_upload_outlined,
        selectedIcon: Icons.cloud_upload,
      ),
      _TabItem(
        label: l10n.navSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
    return PopScope(
      // Allow pop only when already on Home tab; otherwise switch to Home.
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppMainHeader(
          title: l10n.appName,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: l10n.commonMenu,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
              tooltip: l10n.commonNotifications,
            ),
          ],
        ),
        drawer: Consumer(
          builder: (context, ref, _) {
            final debugEnabled = ref.watch(
              debugSettingsProvider.select((settings) => settings.debugEnabled),
            );
            return AppDrawer(
              appName: l10n.appName,
              headerSubtitle: AppConfig.appTagline,
              items: [
                AppDrawerItem(
                  label: l10n.navAlbums,
                  icon: Icons.photo_album_outlined,
                  isSelected: _selectedIndex == 0,
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                    Navigator.of(context).pop();
                  },
                ),
                AppDrawerItem(
                  label: l10n.navUpload,
                  icon: Icons.cloud_upload_outlined,
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.of(context).pop();
                  },
                ),
                AppDrawerItem(
                  label: l10n.navSettings,
                  icon: Icons.settings_outlined,
                  isSelected: _selectedIndex == 2,
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                    Navigator.of(context).pop();
                  },
                ),
                const AppDrawerItem.divider(),
              ],
              bottomItems: [
                AppDrawerItem(
                  label: l10n.drawerDeepLink,
                  icon: Icons.link_outlined,
                  onTap: () => _leaveDrawerFor(context, AppRoutes.deepLink),
                ),
                AppDrawerItem(
                  label: l10n.drawerAbout,
                  icon: Icons.info_outline,
                  onTap: () => _leaveDrawerFor(context, AppRoutes.about),
                ),
                AppDrawerItem(
                  label: l10n.drawerLicenses,
                  icon: Icons.description_outlined,
                  onTap: () {
                    Navigator.of(context).pop();
                    openAppLicensePage(context);
                  },
                ),
                if (debugEnabled) ...[
                  AppDrawerItem(
                    label: l10n.drawerLogs,
                    icon: Icons.list_alt_outlined,
                    onTap: () => _leaveDrawerFor(context, AppRoutes.logs),
                  ),
                  AppDrawerItem(
                    label: l10n.drawerDebug,
                    icon: Icons.bug_report_outlined,
                    onTap: () => _leaveDrawerFor(context, AppRoutes.debug),
                  ),
                ],
              ],
            );
          },
        ),
        body: _buildTabContent(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: tabs
              .map(
                (tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return switch (_selectedIndex) {
      0 => const AlbumsTab(),
      1 => const UploadTab(),
      2 => const _SettingsContent(),
      _ => const AlbumsTab(),
    };
  }

  /// Closes the drawer, then pushes [location].
  ///
  /// The pop has to happen first: `context.push` would otherwise leave the
  /// drawer's route on the stack underneath the new screen.
  static void _leaveDrawerFor(BuildContext context, String location) {
    Navigator.of(context).pop();
    unawaited(context.push<void>(location));
  }
}

// ─── Tab Content ─────────────────────────────────────────────────────────────

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final language = ref.watch(appLanguageProvider);
    final languageNotifier = ref.read(appLanguageProvider.notifier);
    final debugSettings = ref.watch(debugSettingsProvider);
    final debugNotifier = ref.read(debugSettingsProvider.notifier);
    final session = ref.watch(sessionProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      children: [
        AppSectionHeader(title: l10n.settingsTitle),
        const SizedBox(height: AppSpacing.lg),
        // ── Account ─────────────────────────────────────────────────
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.account_circle_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  l10n.settingsSignedInAs,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                subtitle: Text(
                  session.session?.email ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.componentPadding,
                  vertical: AppSpacing.xs,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.logout_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.settingsSignOut,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => unawaited(_confirmSignOut(context, ref)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.componentPadding,
                  vertical: AppSpacing.xs,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ── Theme switcher ──────────────────────────────────────────
        AppSectionHeader(title: l10n.settingsTheme),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              _ThemeOptionTile(
                label: l10n.settingsThemeLight,
                icon: Icons.light_mode_outlined,
                value: ThemeMode.light,
                groupValue: themeMode,
                onChanged: (mode) =>
                    unawaited(themeNotifier.setThemeMode(mode)),
              ),
              const Divider(height: 1),
              _ThemeOptionTile(
                label: l10n.settingsThemeDark,
                icon: Icons.dark_mode_outlined,
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (mode) =>
                    unawaited(themeNotifier.setThemeMode(mode)),
              ),
              const Divider(height: 1),
              _ThemeOptionTile(
                label: l10n.settingsThemeSystem,
                icon: Icons.brightness_auto_outlined,
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (mode) =>
                    unawaited(themeNotifier.setThemeMode(mode)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ── Language switcher ───────────────────────────────────────
        AppSectionHeader(title: l10n.settingsLanguage),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              _LanguageOptionTile(
                label: l10n.settingsLanguageSystem,
                icon: Icons.language_outlined,
                value: AppLanguage.system,
                groupValue: language,
                onChanged: (value) =>
                    unawaited(languageNotifier.setLanguage(value)),
              ),
              const Divider(height: 1),
              _LanguageOptionTile(
                label: l10n.settingsLanguageEnglish,
                icon: Icons.translate_outlined,
                value: AppLanguage.english,
                groupValue: language,
                onChanged: (value) =>
                    unawaited(languageNotifier.setLanguage(value)),
              ),
              const Divider(height: 1),
              _LanguageOptionTile(
                label: l10n.settingsLanguageJapanese,
                icon: Icons.translate_outlined,
                value: AppLanguage.japanese,
                groupValue: language,
                onChanged: (value) =>
                    unawaited(languageNotifier.setLanguage(value)),
              ),
            ],
          ),
        ),
        // ── Developer section (only visible while debug is on) ───────
        if (debugSettings.debugEnabled)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(title: l10n.settingsDeveloper),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: debugSettings.debugEnabled,
                      onChanged: (enabled) =>
                          unawaited(debugNotifier.setDebugEnabled(enabled)),
                      secondary: Icon(
                        Icons.bug_report_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        l10n.settingsDebugMode,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        l10n.settingsDebugModeSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.componentPadding,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    const Divider(height: 1),
                    _LogLevelTile(
                      currentLevel: debugSettings.logLevel,
                      onChanged: (level) =>
                          unawaited(debugNotifier.setLogLevel(level)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        AppListCard(
          title: l10n.settingsDeepLink,
          leading: const Icon(Icons.link_outlined),
          onTap: () => unawaited(context.push<void>(AppRoutes.deepLink)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListCard(
          title: l10n.settingsAbout,
          leading: const Icon(Icons.info_outline),
          onTap: () => unawaited(context.push<void>(AppRoutes.about)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListCard(
          title: l10n.settingsLicenses,
          leading: const Icon(Icons.description_outlined),
          onTap: () => openAppLicensePage(context),
        ),
        if (debugSettings.debugEnabled)
          Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              AppListCard(
                title: l10n.settingsLogs,
                leading: const Icon(Icons.list_alt_outlined),
                onTap: () => unawaited(context.push<void>(AppRoutes.logs)),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppListCard(
                title: l10n.settingsDebug,
                leading: const Icon(Icons.bug_report_outlined),
                onTap: () => unawaited(context.push<void>(AppRoutes.debug)),
              ),
            ],
          ),
      ],
    );
  }

  /// Asks before signing out; the router redirects to the login screen the
  /// moment the session is gone.
  static Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsSignOutConfirmTitle),
        content: Text(l10n.settingsSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsSignOutCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.onSurfaceVariant,
            ),
      onTap: () => onChanged(value),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.componentPadding,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final AppLanguage value;
  final AppLanguage groupValue;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.onSurfaceVariant,
            ),
      onTap: () => onChanged(value),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.componentPadding,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _LogLevelTile extends StatelessWidget {
  const _LogLevelTile({required this.currentLevel, required this.onChanged});

  final LogLevel currentLevel;
  final ValueChanged<LogLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final levels = <(LogLevel, String)>[
      (LogLevel.verbose, l10n.logLevelVerbose),
      (LogLevel.debug, l10n.logLevelDebug),
      (LogLevel.info, l10n.logLevelInfo),
      (LogLevel.warning, l10n.logLevelWarning),
      (LogLevel.error, l10n.logLevelError),
    ];
    return ListTile(
      leading: Icon(Icons.tune_outlined, color: colorScheme.onSurfaceVariant),
      title: Text(
        l10n.settingsLogLevel,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: DropdownButton<LogLevel>(
        value: currentLevel,
        underline: const SizedBox.shrink(),
        onChanged: (level) {
          if (level != null) onChanged(level);
        },
        items: levels
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
            )
            .toList(),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.componentPadding,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
