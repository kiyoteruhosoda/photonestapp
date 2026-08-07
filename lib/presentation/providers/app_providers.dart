import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/ports/app_logger.dart';

/// Message shown when a provider that the composition root is supposed to
/// override is read without an override in place.
String missingOverrideMessage(String providerName) =>
    '$providerName was read without an override.\n'
    'Wired objects come from the composition root: see '
    'lib/app/di/provider_overrides.dart for the app and '
    'test/support/test_harness.dart for widget tests.';

/// The application logging port.
///
/// Declared here with a throwing body and overridden in the composition root.
/// That is what keeps the dependency arrow pointing inward: Presentation
/// names the contract it needs, and `lib/app/` supplies the instance —
/// exactly the role `AppScope` plays for the ChangeNotifier ViewModels,
/// expressed in Riverpod's vocabulary.
final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>((ref) {
  throw UnimplementedError(missingOverrideMessage('appLoggerProvider'));
});
