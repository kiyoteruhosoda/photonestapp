import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';

/// Persists the user's language preference.
final class SetLanguagePreferenceUseCase {
  const SetLanguagePreferenceUseCase(this._repository);

  final LanguagePreferenceRepository _repository;

  Future<void> execute(AppLanguage language) => _repository.save(language);
}
