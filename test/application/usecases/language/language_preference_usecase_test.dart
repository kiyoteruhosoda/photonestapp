import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/language/get_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/language/set_language_preference_usecase.dart';
import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';

final class _FakeLanguagePreferenceRepository
    implements LanguagePreferenceRepository {
  _FakeLanguagePreferenceRepository([this._language = AppLanguage.system]);

  AppLanguage _language;
  final List<AppLanguage> saved = <AppLanguage>[];

  @override
  AppLanguage get() => _language;

  @override
  Future<void> save(AppLanguage language) async {
    saved.add(language);
    _language = language;
  }
}

final class _FailingLanguagePreferenceRepository
    implements LanguagePreferenceRepository {
  @override
  AppLanguage get() => AppLanguage.system;

  @override
  Future<void> save(AppLanguage language) async =>
      throw Exception('storage unavailable');
}

void main() {
  group('GetLanguagePreferenceUseCase', () {
    test('defaults to following the system language', () {
      final repository = _FakeLanguagePreferenceRepository();
      expect(
        GetLanguagePreferenceUseCase(repository).execute(),
        equals(AppLanguage.system),
      );
    });

    for (final language in AppLanguage.values) {
      test('returns ${language.name} when that is what is stored', () {
        final repository = _FakeLanguagePreferenceRepository(language);
        expect(
          GetLanguagePreferenceUseCase(repository).execute(),
          equals(language),
        );
      });
    }
  });

  group('SetLanguagePreferenceUseCase', () {
    for (final language in AppLanguage.values) {
      test('persists ${language.name}', () async {
        final repository = _FakeLanguagePreferenceRepository();
        await SetLanguagePreferenceUseCase(repository).execute(language);
        expect(repository.saved, equals([language]));
      });
    }

    test('propagates a repository failure to the caller', () {
      final useCase = SetLanguagePreferenceUseCase(
        _FailingLanguagePreferenceRepository(),
      );
      expect(useCase.execute(AppLanguage.japanese), throwsA(isA<Exception>()));
    });
  });

  group('Get + Set round-trip', () {
    for (final language in AppLanguage.values) {
      test('round-trips ${language.name}', () async {
        final repository = _FakeLanguagePreferenceRepository();
        await SetLanguagePreferenceUseCase(repository).execute(language);
        expect(
          GetLanguagePreferenceUseCase(repository).execute(),
          equals(language),
        );
      });
    }
  });
}
