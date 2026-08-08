/// Application port to the platform's background task scheduler.
///
/// Behind it sits WorkManager (Infrastructure): the platform periodically
/// wakes the app — even when it has been closed — and runs one auto-upload
/// sync pass. The pass re-checks every precondition itself, so keeping a
/// schedule registered while auto-upload is off would merely waste wake-ups;
/// callers align the schedule with the setting instead.
abstract interface class BackgroundSyncScheduler {
  /// Registers the periodic background sync, replacing nothing when an
  /// identical registration already exists. Safe to call repeatedly.
  Future<void> ensureScheduled();

  /// Removes the periodic background sync. Safe to call when none exists.
  Future<void> cancel();
}
