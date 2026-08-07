/// Language preference as a pure Dart value — no Flutter dependency.
///
/// The Presentation layer maps [system] to the active platform [Locale]
/// (falling back to [english] if the OS language is not supported).
enum AppLanguage {
  /// Always use English.
  english,

  /// Always use Japanese.
  japanese,

  /// Follow the device system language.
  system,
}
