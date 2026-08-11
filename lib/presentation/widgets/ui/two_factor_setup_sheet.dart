import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/account_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/app_state_views.dart';
import 'package:photonest/presentation/widgets/ui/app_text_field.dart';

/// How large the QR is drawn. Big enough for another device's camera at
/// arm's length, small enough to leave the code field on screen.
const double _qrSize = 180;

/// Opens the two-factor enrollment sheet.
///
/// Returns true when the authenticator was registered, and null when the
/// reader backed out — nothing changed on the server in that case, because
/// the secret is only stored once the code proves it arrived.
Future<bool?> showTwoFactorSetupSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const TwoFactorSetupSheet(),
  );
}

/// Registers an authenticator app: fetch a secret, show it, take the code
/// back.
///
/// The secret is fetched when the sheet opens and lives only in this state.
/// Backing out leaves the account exactly as it was, and the next attempt
/// starts from a fresh secret rather than resuming a half-finished one.
class TwoFactorSetupSheet extends ConsumerStatefulWidget {
  const TwoFactorSetupSheet({super.key});

  @override
  ConsumerState<TwoFactorSetupSheet> createState() =>
      _TwoFactorSetupSheetState();
}

class _TwoFactorSetupSheetState extends ConsumerState<TwoFactorSetupSheet> {
  final TextEditingController _code = TextEditingController();

  /// The enrollment being confirmed, or null while it is being fetched.
  TwoFactorEnrollment? _enrollment;

  /// Why the secret could not be fetched, when that is what happened.
  Object? _loadFailure;

  /// True while the confirmation is in flight.
  bool _confirming = false;

  /// Set when the server rejected the code, cleared as soon as the reader
  /// types — the next code the app shows is a different one.
  bool _codeRejected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_begin());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final enrollment = await ref
          .read(manageAccountUseCaseProvider)
          .beginTwoFactorEnrollment();
      if (!mounted) return;
      setState(() => _enrollment = enrollment);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadFailure = error);
    }
  }

  Future<void> _openAuthenticator(Uri uri) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(externalLinkLauncherProvider).open(uri);
    if (!mounted || opened) return;
    // No installed app answers `otpauth://`. That is an outcome, not a
    // failure: the setup key below is the way through, so say that.
    messenger.showSnackBar(SnackBar(content: Text(l10n.accountTwoFactorNoApp)));
  }

  Future<void> _copySecret(String secret) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.accountTwoFactorSecretCopied)),
    );
  }

  Future<void> _confirm(TwoFactorEnrollment enrollment) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _confirming = true);
    try {
      await ref
          .read(manageAccountUseCaseProvider)
          .confirmTwoFactor(secret: enrollment.secret, code: _code.text);
    } on DomainError {
      // A blank code never travels; the field says so.
      if (mounted) {
        setState(() {
          _confirming = false;
          _codeRejected = true;
        });
      }
      return;
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      // A rejected code is the expected failure here and belongs on the
      // field. Anything else is the connection, and belongs in the bar.
      if (error is AuthenticationError || error is InfrastructureError) {
        messenger.showSnackBar(
          SnackBar(content: Text(describeLoadError(error, l10n))),
        );
      }
      setState(() => _codeRejected = true);
      return;
    }
    if (!mounted) return;
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enrollment = _enrollment;
    final failure = _loadFailure;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pageMargin,
          right: AppSpacing.pageMargin,
          top: AppSpacing.pageMargin,
          // Keeps the code field above the keyboard once it opens.
          bottom:
              AppSpacing.pageMargin + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: switch ((enrollment, failure)) {
          (null, final Object error?) => AppErrorView(
            message: describeLoadError(error, l10n),
            onRetry: () {
              setState(() => _loadFailure = null);
              unawaited(_begin());
            },
          ),
          (null, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppLoadingView(),
          ),
          (final TwoFactorEnrollment ready, _) => _Enrollment(
            enrollment: ready,
            code: _code,
            confirming: _confirming,
            codeRejected: _codeRejected,
            onOpenApp: () => unawaited(_openAuthenticator(ready.otpauthUri)),
            onCopySecret: () => unawaited(_copySecret(ready.secret)),
            onCodeChanged: () {
              if (_codeRejected) setState(() => _codeRejected = false);
            },
            onConfirm: () => unawaited(_confirm(ready)),
          ),
        },
      ),
    );
  }
}

class _Enrollment extends StatelessWidget {
  const _Enrollment({
    required this.enrollment,
    required this.code,
    required this.confirming,
    required this.codeRejected,
    required this.onOpenApp,
    required this.onCopySecret,
    required this.onCodeChanged,
    required this.onConfirm,
  });

  final TwoFactorEnrollment enrollment;
  final TextEditingController code;
  final bool confirming;
  final bool codeRejected;
  final VoidCallback onOpenApp;
  final VoidCallback onCopySecret;
  final VoidCallback onCodeChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final qr = enrollment.qrImage?.data?.contentAsBytes();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.accountTwoFactorSetupTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.accountTwoFactorSetupIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          // The one-tap path on a phone: the authenticator registers the
          // account from the URI, with nothing typed.
          FilledButton.icon(
            onPressed: confirming ? null : onOpenApp,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.accountTwoFactorOpenApp),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.accountTwoFactorSecretLabel,
              style: theme.textTheme.bodySmall,
            ),
            subtitle: SelectableText(
              enrollment.secret,
              style: theme.textTheme.bodyLarge,
            ),
            trailing: IconButton(
              onPressed: confirming ? null : onCopySecret,
              tooltip: l10n.accountTwoFactorSecretLabel,
              icon: const Icon(Icons.copy_outlined),
            ),
          ),
          if (qr != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.accountTwoFactorScanHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Image.memory(qr, width: _qrSize, height: _qrSize),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: code,
            label: l10n.accountTwoFactorCodeLabel,
            enabled: !confirming,
            keyboardType: TextInputType.number,
            errorText: codeRejected ? l10n.accountTwoFactorInvalidCode : null,
            onChanged: (_) => onCodeChanged(),
            onSubmitted: (_) => onConfirm(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: confirming ? null : onConfirm,
            child: Text(l10n.accountTwoFactorConfirm),
          ),
        ],
      ),
    );
  }
}
