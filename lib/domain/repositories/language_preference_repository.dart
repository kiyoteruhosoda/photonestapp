import 'package:flutterbase/domain/value_objects/app_language.dart';

/// Persists and retrieves the user's language preference.
///
/// Implementations live in `infrastructure/repositories/`.
abstract interface class LanguagePreferenceRepository {
  /// Returns the currently saved language preference.
  /// Returns [AppLanguage.system] if nothing has been saved yet.
  AppLanguage get();

  /// Persists [language] as the user's preferred language.
  Future<void> save(AppLanguage language);
}
