import 'package:photonest/domain/entities/auth_session.dart';

/// Local persistence of the signed-in session.
///
/// [load] is synchronous like the other preference repositories: the backing
/// store is read into memory once at startup, so restoring a session never
/// blocks the first frame.
abstract interface class SessionRepository {
  /// The stored session, or null when nobody is signed in.
  AuthSession? load();

  /// Stores [session], replacing any previous one.
  Future<void> save(AuthSession session);

  /// Forgets the stored session.
  Future<void> clear();

  /// Emits the stored session after every [save] and [clear].
  ///
  /// The session can change outside any user action — the API client rotates
  /// the token pair transparently, and discards the session entirely when a
  /// refresh is rejected. Observers (the session view model, above all) use
  /// this to stay truthful instead of holding a copy that silently went
  /// stale.
  Stream<AuthSession?> get changes;
}
