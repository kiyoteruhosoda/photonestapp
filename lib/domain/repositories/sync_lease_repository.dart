/// Device-wide mutual exclusion between auto-upload sync passes.
///
/// The foreground app and the background WorkManager engine are separate
/// isolates with separate memory, so an in-memory flag cannot stop them
/// from running the same pass at the same time — and two concurrent passes
/// would read the same upload history and send the same photos twice. The
/// lease lives in shared storage: whoever acquires it runs, everyone else
/// skips this round, and expiry keeps a crashed holder from blocking
/// passes forever.
abstract interface class SyncLeaseRepository {
  /// Takes the sync lease for [holder] until [until] (UTC), when it is
  /// free, expired, or already held by [holder] itself. Returns false when
  /// another live holder has it.
  Future<bool> tryAcquire(
    String holder, {
    required DateTime until,
    required DateTime now,
  });

  /// Releases the lease if [holder] still owns it. Safe to call when the
  /// lease has expired or moved on.
  Future<void> release(String holder);
}
