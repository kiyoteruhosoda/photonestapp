import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the language preference in [SharedPreferences].
final class SharedPreferencesLanguagePreferenceRepository
    implements LanguagePreferenceRepository {
  const SharedPreferencesLanguagePreferenceRepository(this._prefs);

  static const String _key = 'language';

  final SharedPreferences _prefs;

  @override
  AppLanguage get() {
    final saved = _prefs.getString(_key);
    return switch (saved) {
      'english' => AppLanguage.english,
      'japanese' => AppLanguage.japanese,
      _ => AppLanguage.system, // default: follow OS
    };
  }

  @override
  Future<void> save(AppLanguage language) async {
    await _prefs.setString(_key, language.name);
  }
}
