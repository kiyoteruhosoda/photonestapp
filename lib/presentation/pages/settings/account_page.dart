import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/usecases/auth/manage_account_usecase.dart';
import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/account_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

/// The account screen: the two things that keep the reader able to get back
/// into their library — the password and the authenticator.
///
/// Deliberately not a copy of the web admin's account page. What is *not*
/// here (e-mail, display name, passkeys) and why is recorded in
/// `docs/adr/0014-account-screen-covers-credentials-only.md`.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppMainHeader(title: l10n.accountTitle),
      body: switch (account) {
        AsyncLoading<AccountProfile>() => const AppLoadingView(),
        AsyncError<AccountProfile>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () => unawaited(ref.read(accountProvider.notifier).reload()),
        ),
        AsyncData<AccountProfile>(value: final profile) => _AccountBody(
          profile: profile,
        ),
      },
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      children: [
        AppCard(
          child: ListTile(
            leading: Icon(
              Icons.account_circle_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              l10n.accountEmailLabel,
              style: theme.textTheme.bodySmall,
            ),
            subtitle: Text(profile.email, style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: l10n.accountPasswordSection),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(child: _PasswordForm()),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: l10n.accountTwoFactorSection),
        const SizedBox(height: AppSpacing.sm),
        AppCard(child: _TwoFactorSection(enabled: profile.twoFactorEnabled)),
        const SizedBox(height: AppSpacing.lg),
        // Passkeys exist on the server but not here, and a reader who went
        // looking for them deserves to be told where they live rather than
        // to conclude the app lost them.
        Text(l10n.accountPasskeysUnavailable, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Sets a new password.
///
/// Two entries rather than one: the reader cannot see what they typed, and a
/// mistyped password locks them out of every *other* device. The comparison
/// is the only reason the second field exists.
class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  /// What is wrong with the entry, or null while nothing has been rejected.
  /// Held rather than derived so the fields stay quiet until Save is tapped.
  String? _problem;

  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_password.text.length < ManageAccountUseCase.minimumPasswordLength) {
      setState(() {
        _problem = l10n.accountPasswordTooShort(
          ManageAccountUseCase.minimumPasswordLength,
        );
      });
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _problem = l10n.accountPasswordMismatch);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });
    try {
      await ref
          .read(manageAccountUseCaseProvider)
          .changePassword(_password.text);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(describeLoadError(error, l10n))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      // Cleared on success so the new password is not left sitting in two
      // visible-on-toggle fields behind whatever the reader does next.
      _password.clear();
      _confirmation.clear();
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.accountPasswordChanged)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.componentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.accountPasswordHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _password,
            label: l10n.accountPasswordNewLabel,
            obscureText: true,
            enabled: !_saving,
            errorText: _problem,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _confirmation,
            label: l10n.accountPasswordConfirmLabel,
            obscureText: true,
            enabled: !_saving,
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(l10n.accountPasswordChange),
          ),
        ],
      ),
    );
  }
}

/// Turns the authenticator on and off.
class _TwoFactorSection extends ConsumerStatefulWidget {
  const _TwoFactorSection({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_TwoFactorSection> createState() => _TwoFactorSectionState();
}

class _TwoFactorSectionState extends ConsumerState<_TwoFactorSection> {
  bool _busy = false;

  Future<void> _enable() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final registered = await showTwoFactorSetupSheet(context);
    if (!mounted || registered != true) return;
    ref.read(accountProvider.notifier).setTwoFactor(enabled: true);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.accountTwoFactorEnabled)),
    );
  }

  Future<void> _disable() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountTwoFactorDisableConfirmTitle),
        content: Text(l10n.accountTwoFactorDisableConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountTwoFactorDisable),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(manageAccountUseCaseProvider).disableTwoFactor();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(describeLoadError(error, l10n))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(accountProvider.notifier).setTwoFactor(enabled: false);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.accountTwoFactorDisabled)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = widget.enabled;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.componentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            enabled ? l10n.accountTwoFactorOn : l10n.accountTwoFactorOff,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (enabled)
            OutlinedButton(
              onPressed: _busy ? null : () => unawaited(_disable()),
              child: Text(l10n.accountTwoFactorDisable),
            )
          else
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_enable()),
              child: Text(l10n.accountTwoFactorEnable),
            ),
        ],
      ),
    );
  }
}
