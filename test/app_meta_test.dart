import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/app/constants.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('version', () {
    test('pubspec version matches kAppVersion', () {
      final RegExpMatch? match = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
        multiLine: true,
      ).firstMatch(read('pubspec.yaml'));
      expect(match, isNotNull, reason: 'version must look like 1.0.0+1');
      expect(match!.group(1), kAppVersion);
      expect(int.parse(match.group(2) ?? '0'), greaterThanOrEqualTo(1));
    });
  });

  group('package id', () {
    final RegExp idPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

    test('looks like a valid application id', () {
      expect(idPattern.hasMatch(kApplicationId), isTrue);
    });

    test('Gradle uses the same id as the Dart constant', () {
      final String gradle = read('android/app/build.gradle.kts');
      expect(gradle, contains('applicationId = "$kApplicationId"'));
      expect(gradle, contains('namespace = "$kApplicationId"'));
    });

    test('MainActivity lives in the matching folder and package', () {
      final String folder = kApplicationId.replaceAll('.', '/');
      final File activity = File('android/app/src/main/kotlin/$folder/MainActivity.kt');
      expect(activity.existsSync(), isTrue);
      expect(activity.readAsStringSync(), contains('package $kApplicationId'));
    });
  });

  group('Android manifest', () {
    final String manifest = read('android/app/src/main/AndroidManifest.xml');

    test('has the ad id placeholder and portrait lock', () {
      expect(manifest, contains(r'${admobAppId}'));
      expect(manifest, contains('android:screenOrientation="portrait"'));
    });

    test('asks only for the permissions that ads need', () {
      final Set<String> permissions = RegExp(r'<uses-permission android:name="([^"]+)"')
          .allMatches(manifest)
          .map((RegExpMatch m) => m.group(1) ?? '')
          .toSet();
      expect(permissions, <String>{
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
        'com.google.android.gms.permission.AD_ID',
      });
    });
  });

  group('store information', () {
    test('contact e-mail and policy link look right', () {
      expect(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(kContactEmail), isTrue);
      expect(kPrivacyPolicyUrl, startsWith('https://'));
      expect(kPlayStoreWebUrl, contains(kApplicationId));
      expect(kPlayStoreMarketUrl, contains(kApplicationId));
    });
  });

  group('assets', () {
    test('the declared asset files exist', () {
      expect(File('assets/config/game_config.json').existsSync(), isTrue);
      final Directory images = Directory('assets/images');
      expect(images.existsSync(), isTrue);
      expect(images.listSync().whereType<File>(), isNotEmpty,
          reason: 'pubspec declares assets/images/, which must contain a file');
    });

    test('launcher icons exist for every density', () {
      const List<String> densities = <String>['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final String density in densities) {
        for (final String name in <String>[
          'ic_launcher.png',
          'ic_launcher_round.png',
          'ic_launcher_foreground.png',
          'ic_launcher_monochrome.png',
        ]) {
          final String path = 'android/app/src/main/res/mipmap-$density/$name';
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
      expect(File('android/app/src/main/res/drawable-nodpi/launch_logo.png').existsSync(), isTrue);
    });
  });
}
