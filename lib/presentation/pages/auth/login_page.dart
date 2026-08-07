import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutterbase/presentation/app_scope.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/viewmodels/session_viewmodel.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// Sign-in screen: server address, e-mail, password.
///
/// Navigation away from here is not this page's job — the router redirects
/// as soon as [SessionViewModel] reports a session, so a successful login
/// needs no explicit `go()`.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final lastServer = AppScope.of(context).sessionViewModel.lastServerUrl;
    if (lastServer != null) {
      _serverController.text = lastServer.toString();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(SessionViewModel session) async {
    await session.login(
      serverUrl: _serverController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = AppScope.of(context).sessionViewModel;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListenableBuilder(
                listenable: session,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.loginTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.loginSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      controller: _serverController,
                      label: l10n.loginServerLabel,
                      hint: l10n.loginServerHint,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      enabled: !session.busy,
                      prefixIcon: const Icon(Icons.dns_outlined),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _emailController,
                      label: l10n.loginEmailLabel,
                      hint: l10n.loginEmailHint,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !session.busy,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _passwordController,
                      label: l10n.loginPasswordLabel,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      enabled: !session.busy,
                      prefixIcon: const Icon(Icons.lock_outline),
                      onSubmitted: (_) => unawaited(_submit(session)),
                    ),
                    if (session.lastFailure != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _describe(session.lastFailure!, l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (session.busy)
                      const Center(child: CircularProgressIndicator())
                    else
                      AppPrimaryButton(
                        label: l10n.loginSubmit,
                        onPressed: () => unawaited(_submit(session)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _describe(LoginFailure failure, AppLocalizations l10n) =>
      switch (failure) {
        LoginFailure.invalidInput => l10n.loginErrorInvalidInput,
        LoginFailure.invalidCredentials => l10n.loginErrorInvalidCredentials,
        LoginFailure.network => l10n.loginErrorNetwork,
      };
}
