import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/ports/external_link_launcher.dart';
import 'package:photonest/application/usecases/auth/manage_account_usecase.dart';
import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/presentation/providers/app_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────

final Provider<ManageAccountUseCase> manageAccountUseCaseProvider =
    Provider<ManageAccountUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('manageAccountUseCaseProvider'),
      );
    });

// ─── Screen state ──────────────────────────────────────────────────────────

/// The signed-in account, as the account screen shows it.
final AsyncNotifierProvider<AccountNotifier, AccountProfile> accountProvider =
    AsyncNotifierProvider<AccountNotifier, AccountProfile>(AccountNotifier.new);

/// Loads the account and keeps it in step with the credential changes made
/// from the screen.
class AccountNotifier extends AsyncNotifier<AccountProfile> {
  @override
  Future<AccountProfile> build() {
    // Rebuilds when the signed-in identity changes, so signing into another
    // account never shows the previous one's e-mail or two-factor state.
    ref.watch(sessionIdentityProvider);
    return ref.read(manageAccountUseCaseProvider).load();
  }

  /// Re-reads the account from the server.
  Future<void> reload() async {
    state = const AsyncValue<AccountProfile>.loading();
    state = await AsyncValue.guard(
      () => ref.read(manageAccountUseCaseProvider).load(),
    );
  }

  /// Records that the authenticator was turned on or off.
  ///
  /// Patched rather than re-read: the server has already confirmed the
  /// change, and a re-read that failed would replace a correct screen with
  /// the error state — over one boolean the app already knows.
  void setTwoFactor({required bool enabled}) {
    final loaded = state.value;
    if (loaded == null) return;
    state = AsyncValue.data(loaded.withTwoFactor(enabled: enabled));
  }
}

/// Opens a link outside the app.
///
/// A port seam rather than a use case: `open` decides nothing and
/// coordinates nothing, so wrapping it in an Application-layer class would
/// add a layer that only forwards. The account screen uses it for the
/// `otpauth://` URI, which is what lets an authenticator register this
/// account with one tap instead of a copied key.
final Provider<ExternalLinkLauncher> externalLinkLauncherProvider =
    Provider<ExternalLinkLauncher>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('externalLinkLauncherProvider'),
      );
    });
