import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/app_scope.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';
import 'package:go_router/go_router.dart';

/// Main screen with bottom navigation.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <_TabItem>[
      _TabItem(
        label: l10n.navHome,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _TabItem(
        label: l10n.navSearch,
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
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
        drawer: ListenableBuilder(
          listenable: AppScope.of(context).debugSettingsViewModel,
          builder: (context, _) {
            final debugEnabled = AppScope.of(
              context,
            ).debugSettingsViewModel.debugEnabled;
            return AppDrawer(
              appName: l10n.appName,
              headerSubtitle: AppConfig.appTagline,
              items: [
                AppDrawerItem(
                  label: l10n.navHome,
                  icon: Icons.home_outlined,
                  isSelected: _selectedIndex == 0,
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                    Navigator.of(context).pop();
                  },
                ),
                AppDrawerItem(
                  label: l10n.navSearch,
                  icon: Icons.search_outlined,
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
                  label: l10n.drawerBookmarks,
                  icon: Icons.bookmark_outline,
                  onTap: () => _leaveDrawerFor(context, AppRoutes.bookmarks),
                ),
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
      0 => const _HomeContent(),
      1 => const _SearchContent(),
      2 => const _SettingsContent(),
      _ => const _HomeContent(),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      children: [
        AppSectionHeader(
          title: l10n.homeWelcomeTitle,
          subtitle: AppConfig.homeSubtitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.homeCardTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.homeCardBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: l10n.homeComponentsTitle),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: l10n.homePrimaryButton,
          onPressed: () {},
          width: double.infinity,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: l10n.homeSecondaryButton,
          onPressed: () {},
          width: double.infinity,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.homeTextFieldLabel,
          hint: l10n.homeTextFieldHint,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppListCard(
          title: l10n.homeListCardTitle,
          subtitle: l10n.homeListCardSubtitle,
          leading: const Icon(Icons.article_outlined),
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListCard(
          title: l10n.homeListCardItem2,
          subtitle: l10n.homeListCardSubtitle,
          leading: const Icon(Icons.article_outlined),
          onTap: () {},
        ),
      ],
    );
  }
}

class _SearchContent extends StatelessWidget {
  const _SearchContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      child: Column(
        children: [
          AppTextField(
            label: l10n.searchFieldLabel,
            hint: l10n.searchFieldHint,
            prefixIcon: const Icon(Icons.search),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppEmptyView(message: l10n.searchEmptyMessage, icon: Icons.search),
        ],
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final themeViewModel = scope.themeViewModel;
    final languageViewModel = scope.languageViewModel;
    final debugViewModel = scope.debugSettingsViewModel;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      children: [
        AppSectionHeader(title: l10n.settingsTitle),
        const SizedBox(height: AppSpacing.lg),
        // ── Theme switcher ──────────────────────────────────────────
        AppSectionHeader(title: l10n.settingsTheme),
        const SizedBox(height: AppSpacing.sm),
        ListenableBuilder(
          listenable: themeViewModel,
          builder: (context, _) => AppCard(
            child: Column(
              children: [
                _ThemeOptionTile(
                  label: l10n.settingsThemeLight,
                  icon: Icons.light_mode_outlined,
                  value: ThemeMode.light,
                  groupValue: themeViewModel.themeMode,
                  onChanged: themeViewModel.setThemeMode,
                ),
                const Divider(height: 1),
                _ThemeOptionTile(
                  label: l10n.settingsThemeDark,
                  icon: Icons.dark_mode_outlined,
                  value: ThemeMode.dark,
                  groupValue: themeViewModel.themeMode,
                  onChanged: themeViewModel.setThemeMode,
                ),
                const Divider(height: 1),
                _ThemeOptionTile(
                  label: l10n.settingsThemeSystem,
                  icon: Icons.brightness_auto_outlined,
                  value: ThemeMode.system,
                  groupValue: themeViewModel.themeMode,
                  onChanged: themeViewModel.setThemeMode,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ── Language switcher ───────────────────────────────────────
        AppSectionHeader(title: l10n.settingsLanguage),
        const SizedBox(height: AppSpacing.sm),
        ListenableBuilder(
          listenable: languageViewModel,
          builder: (context, _) => AppCard(
            child: Column(
              children: [
                _LanguageOptionTile(
                  label: l10n.settingsLanguageSystem,
                  icon: Icons.language_outlined,
                  value: AppLanguage.system,
                  groupValue: languageViewModel.language,
                  onChanged: languageViewModel.setLanguage,
                ),
                const Divider(height: 1),
                _LanguageOptionTile(
                  label: l10n.settingsLanguageEnglish,
                  icon: Icons.translate_outlined,
                  value: AppLanguage.english,
                  groupValue: languageViewModel.language,
                  onChanged: languageViewModel.setLanguage,
                ),
                const Divider(height: 1),
                _LanguageOptionTile(
                  label: l10n.settingsLanguageJapanese,
                  icon: Icons.translate_outlined,
                  value: AppLanguage.japanese,
                  groupValue: languageViewModel.language,
                  onChanged: languageViewModel.setLanguage,
                ),
              ],
            ),
          ),
        ),
        // ── Developer section (only visible while debug is on) ───────
        ListenableBuilder(
          listenable: debugViewModel,
          builder: (context, _) {
            if (!debugViewModel.debugEnabled) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                AppSectionHeader(title: l10n.settingsDeveloper),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: debugViewModel.debugEnabled,
                        onChanged: debugViewModel.setDebugEnabled,
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
                        currentLevel: debugViewModel.logLevel,
                        onChanged: debugViewModel.setLogLevel,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppListCard(
          title: l10n.settingsBookmarks,
          leading: const Icon(Icons.bookmark_outline),
          onTap: () => unawaited(context.push<void>(AppRoutes.bookmarks)),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        ListenableBuilder(
          listenable: debugViewModel,
          builder: (context, _) => debugViewModel.debugEnabled
              ? Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    AppListCard(
                      title: l10n.settingsLogs,
                      leading: const Icon(Icons.list_alt_outlined),
                      onTap: () =>
                          unawaited(context.push<void>(AppRoutes.logs)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppListCard(
                      title: l10n.settingsDebug,
                      leading: const Icon(Icons.bug_report_outlined),
                      onTap: () =>
                          unawaited(context.push<void>(AppRoutes.debug)),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
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
