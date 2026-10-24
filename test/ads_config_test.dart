import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/services/ads_config.dart';
import 'package:chai_tapri/services/ads_service.dart';

const String unitA = 'ca-app-pub-1234567890123456/1234567890';
const String unitB = 'ca-app-pub-1234567890123456/0987654321';

AdsConfig resolve({
  String mode = 'prod',
  bool isRelease = true,
  String defaultUnit = '',
  Map<AdPlacement, String> units = const <AdPlacement, String>{},
}) {
  return AdsConfig.resolve(
    mode: mode,
    isRelease: isRelease,
    defaultUnitId: defaultUnit,
    placementUnitIds: units,
  );
}

void main() {
  group('isValidAdUnitId', () {
    test('accepts ad unit ids', () {
      expect(isValidAdUnitId(unitA), isTrue);
      expect(isValidAdUnitId(' $unitA '), isTrue);
      expect(isValidAdUnitId(kTestRewardedAdUnitId), isTrue);
    });

    test('rejects everything else', () {
      expect(isValidAdUnitId(''), isFalse);
      expect(isValidAdUnitId('ca-app-pub-1234567890123456~1234567890'), isFalse,
          reason: 'that is an application id');
      expect(isValidAdUnitId('ca-app-pub-123/456'), isFalse);
      expect(isValidAdUnitId('ca-app-pub-1234567890123456/12345'), isFalse);
      expect(isValidAdUnitId('hello'), isFalse);
    });
  });

  group('test ads', () {
    test('test mode always uses the Google test unit', () {
      final AdsConfig config = resolve(mode: 'test', defaultUnit: unitA);
      expect(config.usesTestAds, isTrue);
      for (final AdPlacement placement in AdPlacement.values) {
        expect(config.unitIdFor(placement), kTestRewardedAdUnitId);
      }
    });

    test('debug and profile builds use test ads even with prod settings', () {
      final AdsConfig config = resolve(isRelease: false, defaultUnit: unitA);
      expect(config.usesTestAds, isTrue);
      expect(config.unitIdFor(AdPlacement.boost), kTestRewardedAdUnitId);
    });

    test('an unknown mode is treated as test', () {
      final AdsConfig config = resolve(mode: 'banana', defaultUnit: unitA);
      expect(config.usesTestAds, isTrue);
    });
  });

  group('production ads', () {
    test('the default unit serves every placement', () {
      final AdsConfig config = resolve(defaultUnit: unitA);
      expect(config.usesTestAds, isFalse);
      expect(config.hasAnyUnit, isTrue);
      for (final AdPlacement placement in AdPlacement.values) {
        expect(config.unitIdFor(placement), unitA);
      }
    });

    test('the mode is not case sensitive and ignores spaces', () {
      final AdsConfig config = resolve(mode: ' PROD ', defaultUnit: unitA);
      expect(config.usesTestAds, isFalse);
    });

    test('a placement unit beats the default unit', () {
      final AdsConfig config = resolve(
        defaultUnit: unitA,
        units: <AdPlacement, String>{AdPlacement.boost: unitB},
      );
      expect(config.unitIdFor(AdPlacement.boost), unitB);
      expect(config.unitIdFor(AdPlacement.vipDouble), unitA);
    });

    test('an invalid unit disables only that placement', () {
      final AdsConfig config = resolve(
        defaultUnit: unitA,
        units: <AdPlacement, String>{AdPlacement.boost: 'oops'},
      );
      expect(config.unitIdFor(AdPlacement.boost), isNull);
      expect(config.unitIdFor(AdPlacement.dailyDouble), unitA);
      expect(config.hasAnyUnit, isTrue);
    });

    test('without any valid unit nothing is shown', () {
      final AdsConfig config = resolve(defaultUnit: 'nope');
      expect(config.hasAnyUnit, isFalse);
      expect(config.unitIdFor(AdPlacement.boost), isNull);
    });

    test('production never falls back to the test unit', () {
      final AdsConfig config = resolve();
      for (final AdPlacement placement in AdPlacement.values) {
        expect(config.unitIdFor(placement), isNull);
      }
    });
  });

  test('none has no units', () {
    expect(AdsConfig.none.hasAnyUnit, isFalse);
  });
}
