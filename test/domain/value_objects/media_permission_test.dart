import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/value_objects/media_permission.dart';

void main() {
  AuthSession sessionWith(List<String> scopes) => AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    email: 'user@example.com',
    scopes: scopes,
  );

  group('MediaPermission', () {
    test('names the permission code the server asks for', () {
      expect(MediaPermission.tagMedia.scope, 'media:tag-manage');
      expect(MediaPermission.markFavorite.scope, 'media:metadata-manage');
      expect(MediaPermission.trashMedia.scope, 'media:delete');
      expect(MediaPermission.uploadMedia.scope, 'media:upload');
    });
  });

  group('GrantedPermissions', () {
    test('allows only what the session was granted', () {
      final granted = GrantedPermissions.of(
        sessionWith(const ['media:view', 'media:upload']),
      );

      expect(granted.allows(MediaPermission.uploadMedia), isTrue);
      expect(granted.allows(MediaPermission.trashMedia), isFalse);
      expect(granted.allows(MediaPermission.tagMedia), isFalse);
      expect(granted.allows(MediaPermission.markFavorite), isFalse);
    });

    test('a signed-out session may do nothing', () {
      final granted = GrantedPermissions.of(null);

      for (final permission in MediaPermission.values) {
        expect(granted.allows(permission), isFalse, reason: permission.name);
      }
    });

    test('a scope the app does not act on grants nothing', () {
      final granted = GrantedPermissions.of(
        sessionWith(const ['system:manage', 'user:manage']),
      );

      for (final permission in MediaPermission.values) {
        expect(granted.allows(permission), isFalse, reason: permission.name);
      }
    });

    test('equality is the set of permissions, not the scope order', () {
      const forwards = ['media:upload', 'media:view'];
      const backwards = ['media:view', 'media:upload'];
      expect(
        GrantedPermissions.of(sessionWith(forwards)),
        GrantedPermissions.of(sessionWith(backwards)),
      );
      expect(
        GrantedPermissions.of(sessionWith(const ['media:upload'])),
        isNot(GrantedPermissions.of(sessionWith(const ['media:delete']))),
      );
    });

    test('toString names the scopes, so a log explains a hidden control', () {
      expect(
        GrantedPermissions.of(sessionWith(const ['media:upload'])).toString(),
        contains('media:upload'),
      );
    });
  });
}
