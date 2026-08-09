import 'package:photonest/domain/entities/auth_session.dart';

/// An operation the app performs against the server's media, paired with the
/// permission code the server demands for it.
///
/// The server refuses an unpermitted call with 403, and it refuses it *after*
/// the reader has already chosen tags or confirmed a deletion. Naming the
/// requirement here lets the Presentation layer ask before it offers the
/// control, so the refusal is never something the reader discovers by
/// running into it.
enum MediaPermission {
  /// `PUT /media/{id}/tags` — replacing the tags on one media item.
  tagMedia('media:tag-manage'),

  /// `POST /media/{id}/favorite` — flipping the favourite mark.
  markFavorite('media:metadata-manage'),

  /// `DELETE /media/{id}` and `POST /media/{id}/restore` — moving media to
  /// the trash and bringing it back. One code covers both: the server guards
  /// the way back with the same permission as the way in.
  trashMedia('media:delete'),

  /// `POST /upload/chunks` and the rest of the chunked upload — sending a
  /// device photo to the server.
  uploadMedia('media:upload');

  const MediaPermission(this.scope);

  /// The permission code the server's endpoint requires.
  final String scope;
}

/// The permissions the signed-in session actually holds.
///
/// Built from the scopes the server issued at login, so a reader whose role
/// lost a permission stops being offered it at the next token refresh rather
/// than at the next 403.
final class GrantedPermissions {
  const GrantedPermissions(this._granted);

  /// What [session] may do. A null session — signed out — may do nothing.
  factory GrantedPermissions.of(AuthSession? session) {
    if (session == null) return const GrantedPermissions(<MediaPermission>{});
    return GrantedPermissions(<MediaPermission>{
      for (final permission in MediaPermission.values)
        if (session.hasScope(permission.scope)) permission,
    });
  }

  final Set<MediaPermission> _granted;

  /// Whether the session may perform [permission].
  bool allows(MediaPermission permission) => _granted.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GrantedPermissions &&
          other._granted.length == _granted.length &&
          other._granted.containsAll(_granted));

  @override
  int get hashCode => Object.hashAllUnordered(_granted);

  @override
  String toString() =>
      'GrantedPermissions(${_granted.map((p) => p.scope).join(', ')})';
}
