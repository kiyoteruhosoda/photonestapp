/// Persistence of the automatic-upload preference.
abstract interface class AutoUploadSettingsRepository {
  /// Whether newly taken photos should be uploaded automatically.
  bool isEnabled();

  /// Instant (UTC) from which photos count as "new".
  ///
  /// Stamped by the implementation the first time auto-upload is switched
  /// on, so enabling the feature never drags the whole existing camera roll
  /// into the upload queue. Null while auto-upload has never been enabled.
  DateTime? enabledSince();

  /// Whether automatic upload is restricted to unmetered connections.
  ///
  /// Defaults to true: the feature sends photo and video *originals*, so
  /// letting it run on a mobile connection by default would spend someone's
  /// data allowance without them ever choosing to.
  bool isUnmeteredOnly();

  /// Device album ids automatic upload is limited to.
  ///
  /// Empty means the whole library — the default, and what an install that
  /// predates this setting keeps. Ids of albums that no longer exist stay
  /// in the set: an album can come back (a removable card remounted), and
  /// silently dropping the choice would widen the target behind the user's
  /// back.
  Set<String> backupAlbumIds();

  /// Turns automatic upload on or off.
  Future<void> setEnabled(bool enabled);

  /// Limits automatic upload to [albumIds], or lifts the limit when empty.
  Future<void> setBackupAlbumIds(Set<String> albumIds);

  /// Restricts automatic upload to unmetered connections, or lifts the
  /// restriction.
  Future<void> setUnmeteredOnly(bool unmeteredOnly);
}
