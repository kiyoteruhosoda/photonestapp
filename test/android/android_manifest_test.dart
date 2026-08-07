import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/shared/app_config.dart';

/// Guards the half of the deep-link contract that lives outside Dart.
///
/// `AppConfig` and `AndroidManifest.xml` have to name the same host and the
/// same scheme. When they drift, nothing fails at build time: Android simply
/// never verifies the domain, and every App Link opens in the browser — the
/// slowest possible way to find out. These assertions turn that into a test
/// failure instead.
void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  group('AndroidManifest — deep links', () {
    test('hands incoming links to the Flutter router', () {
      // Without this the intent filters still launch the app, but it always
      // starts at "/" and the link's path is lost.
      expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    });

    test('declares the deep-link opt-in inside <activity>', () {
      // FlutterActivity.getMetaData() reads ActivityInfo.metaData, so the
      // same <meta-data> under <application> is never read — and nothing
      // reports the mistake. The app just always opens at "/".
      final activity = RegExp(
        r'<activity\b.*?</activity>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(activity, isNotNull, reason: 'no <activity> element found');
      expect(
        activity!.group(0),
        contains('android:name="flutter_deeplinking_enabled"'),
        reason:
            'flutter_deeplinking_enabled must sit inside <activity>; under '
            '<application> it is silently ignored.',
      );
    });

    test('declares an autoVerify filter for the configured host', () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(
        manifest,
        contains('android:host="${AppConfig.appLinkHost}"'),
        reason:
            'AndroidManifest.xml and AppConfig.appLinkHost must name the '
            'same host, or domain verification will never succeed.',
      );
      expect(manifest, contains('android:scheme="${AppConfig.appLinkScheme}"'));
    });

    test('declares the custom scheme AppConfig builds links for', () {
      expect(
        manifest,
        contains('android:scheme="${AppConfig.customLinkScheme}"'),
      );
    });

    test('the deep-link filters are browsable', () {
      // A filter without BROWSABLE is unreachable from a browser or from
      // `adb ... -c android.intent.category.BROWSABLE`.
      expect(
        'android.intent.category.BROWSABLE'.allMatches(manifest).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('the activity stays exported, or no link can reach it', () {
      expect(manifest, contains('android:exported="true"'));
    });

    test('every scheme a bookmark may use is visible to canLaunchUrl', () {
      // The <queries> block gates package visibility on API 30+. A scheme
      // the domain accepts but that is missing here makes canLaunchUrl
      // report an openable URL as unopenable.
      final queries = RegExp(
        r'<queries>.*?</queries>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(queries, isNotNull, reason: 'no <queries> element found');

      for (final scheme in allowedBookmarkSchemes) {
        expect(
          queries!.group(0),
          contains('android:scheme="$scheme"'),
          reason:
              '"$scheme" is in allowedBookmarkSchemes, so <queries> has to '
              'declare it too.',
        );
      }
    });
  });

  group('assetlinks.json template', () {
    test('is valid JSON with the fields Android verifies', () {
      final file = File('docs/deep_links/assetlinks.json');
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(contents, contains('delegate_permission/common.handle_all_urls'));
      expect(contents, contains('sha256_cert_fingerprints'));
      expect(contents, contains('package_name'));
    });

    test('names the same application id as the Gradle build', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      final match = RegExp(
        r'def appApplicationId\s*=\s*"([^"]+)"',
      ).firstMatch(gradle);
      expect(match, isNotNull, reason: 'appApplicationId not found');

      expect(
        File('docs/deep_links/assetlinks.json').readAsStringSync(),
        contains('"package_name": "${match!.group(1)}"'),
        reason:
            'The assetlinks.json template must name the application id the '
            'APK is actually built with.',
      );
    });
  });

  group('minSdk', () {
    test('is the same in Gradle and in the launcher-icon generator', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      final gradleMin = RegExp(r'minSdk\s*=\s*(\d+)').firstMatch(gradle);
      final iconMin = RegExp(r'min_sdk_android:\s*(\d+)').firstMatch(pubspec);

      expect(gradleMin, isNotNull);
      expect(iconMin, isNotNull);
      expect(
        iconMin!.group(1),
        gradleMin!.group(1),
        reason:
            'flutter_launcher_icons uses min_sdk_android to decide which '
            'legacy mipmap variants to emit; it has to match the real '
            'minSdk.',
      );
    });
  });
}
