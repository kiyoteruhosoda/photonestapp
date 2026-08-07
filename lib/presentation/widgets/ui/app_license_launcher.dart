import 'package:flutter/material.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/shared/app_config.dart';
import 'package:flutterbase/shared/build_info.dart';

/// Opens the built-in [showLicensePage] with the app's branding applied.
///
/// License entries are sourced from [LicenseRegistry]; Flutter auto-registers
/// package licenses, and additional in-app entries are contributed via
/// `AppLicenseRegistrar.register()` during startup.
void openAppLicensePage(BuildContext context) {
  showLicensePage(
    context: context,
    applicationName: AppConfig.appName,
    applicationVersion: BuildInfo.version,
    applicationIcon: const _AppLicenseIcon(),
    applicationLegalese: '© ${AppConfig.appName}',
  );
}

class _AppLicenseIcon extends StatelessWidget {
  const _AppLicenseIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Container(
        width: AppSpacing.aboutIconContainer,
        height: AppSpacing.aboutIconContainer,
        decoration: const BoxDecoration(
          color: AppColors.brandContainer,
          borderRadius: AppRadius.xlBorder,
        ),
        child: const Icon(
          Icons.web_asset,
          size: AppSpacing.aboutIconSize,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
