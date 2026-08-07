import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_language_preference_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPreferencesLanguagePreferenceRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPreferencesLanguagePreferenceRepository(prefs);
  });

  group('SharedPreferencesLanguagePreferenceRepository', () {
    test('returns system by default when nothing is stored', () {
      expect(repo.get(), equals(AppLanguage.system));
    });

    test('saves and restores English', () async {
      await repo.save(AppLanguage.english);
      final repo2 = SharedPreferencesLanguagePreferenceRepository(prefs);
      expect(repo2.get(), equals(AppLanguage.english));
    });

    test('saves and restores Japanese', () async {
      await repo.save(AppLanguage.japanese);
      final repo2 = SharedPreferencesLanguagePreferenceRepository(prefs);
      expect(repo2.get(), equals(AppLanguage.japanese));
    });

    test('saves and restores system preference', () async {
      await repo.save(AppLanguage.system);
      final repo2 = SharedPreferencesLanguagePreferenceRepository(prefs);
      expect(repo2.get(), equals(AppLanguage.system));
    });

    test('unknown stored value falls back to system', () async {
      await prefs.setString('language', 'corrupted');
      final repo2 = SharedPreferencesLanguagePreferenceRepository(prefs);
      expect(repo2.get(), equals(AppLanguage.system));
    });

    test('all AppLanguage values round-trip correctly', () async {
      for (final lang in AppLanguage.values) {
        await repo.save(lang);
        final repo2 = SharedPreferencesLanguagePreferenceRepository(prefs);
        expect(
          repo2.get(),
          equals(lang),
          reason: 'language=$lang failed round-trip',
        );
      }
    });
  });
}
