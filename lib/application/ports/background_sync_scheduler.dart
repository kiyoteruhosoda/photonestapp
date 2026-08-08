/// Application port to the platform's background task scheduler.
///
/// Behind it sits WorkManager (Infrastructure): the platform periodically
/// wakes the app — even when it has been closed — and runs one auto-upload
/// sync pass. The pass re-checks every precondition itself, so keeping a
/// schedule registered while auto-upload is off would merely waste wake-ups;
/// callers align the schedule with the setting instead.
abstract interface class BackgroundSyncScheduler {
  /// Registers the periodic background sync, updating the existing
  /// registration in place when there is one. Safe to call repeatedly.
  ///
  /// With [unmeteredOnly] the platform only wakes the app while the
  /// connection is unmetered, so a pass never starts on a mobile network in
  /// the first place. The flag is part of the registration rather than
  /// something the pass re-reads, which is why callers must call this again
  /// after the setting changes.
  Future<void> ensureScheduled({required bool unmeteredOnly});

  /// Removes the periodic background sync. Safe to call when none exists.
  Future<void> cancel();
}
