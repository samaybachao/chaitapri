import 'package:flutter/foundation.dart';

import 'package:chai_tapri/services/ads_service.dart';

/// Google's public TEST rewarded ad unit. It always fills and never pays, so it is
/// safe to click while developing and in closed-test builds.
const String kTestRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// Ad unit ids look like `ca-app-pub-1234567890123456/1234567890`
/// (the application id has a `~` instead of the `/` and goes into ADMOB_APP_ID).
final RegExp _adUnitPattern = RegExp(r'^ca-app-pub-\d{16}/\d{10}$');

/// True when [id] has the shape of an AdMob ad unit id.
bool isValidAdUnitId(String id) => _adUnitPattern.hasMatch(id.trim());

/// Which ad units the app uses. Built from the `--dart-define-from-file=env/<file>.json`
/// values, see README.md.
///
///  * Debug and profile builds, and release builds with `ADS_MODE=test` (the default),
///    always use Google's test ad unit.
///  * Release builds with `ADS_MODE=prod` use your own ad units. A placement without a
///    valid ad unit simply shows no ad.
class AdsConfig {
  const AdsConfig._({required this.usesTestAds, required Map<AdPlacement, String> unitIds})
    : _unitIds = unitIds;

  /// Builds the config from the compile-time values.
  factory AdsConfig.fromEnvironment() {
    return AdsConfig.resolve(
      mode: const String.fromEnvironment('ADS_MODE', defaultValue: 'test'),
      isRelease: kReleaseMode,
      defaultUnitId: const String.fromEnvironment('ADMOB_REWARDED_ID'),
      placementUnitIds: const <AdPlacement, String>{
        AdPlacement.boost: String.fromEnvironment('ADMOB_REWARDED_BOOST_ID'),
        AdPlacement.freeHelper: String.fromEnvironment('ADMOB_REWARDED_HELPER_ID'),
        AdPlacement.offlineDouble: String.fromEnvironment('ADMOB_REWARDED_OFFLINE_ID'),
        AdPlacement.vipDouble: String.fromEnvironment('ADMOB_REWARDED_VIP_ID'),
        AdPlacement.dailyDouble: String.fromEnvironment('ADMOB_REWARDED_DAILY_ID'),
      },
    );
  }

  /// The decision logic, separated so tests can try every combination.
  factory AdsConfig.resolve({
    required String mode,
    required bool isRelease,
    required String defaultUnitId,
    required Map<AdPlacement, String> placementUnitIds,
  }) {
    final bool production = isRelease && mode.trim().toLowerCase() == 'prod';
    final Map<AdPlacement, String> ids = <AdPlacement, String>{};
    for (final AdPlacement placement in AdPlacement.values) {
      if (!production) {
        ids[placement] = kTestRewardedAdUnitId;
        continue;
      }
      final String specific = (placementUnitIds[placement] ?? '').trim();
      final String chosen = specific.isNotEmpty ? specific : defaultUnitId.trim();
      if (isValidAdUnitId(chosen)) {
        ids[placement] = chosen;
      }
    }
    return AdsConfig._(usesTestAds: !production, unitIds: Map<AdPlacement, String>.unmodifiable(ids));
  }

  /// A config without any ad unit (ads off).
  static const AdsConfig none = AdsConfig._(
    usesTestAds: true,
    unitIds: <AdPlacement, String>{},
  );

  /// True when Google's test ads are used.
  final bool usesTestAds;

  final Map<AdPlacement, String> _unitIds;

  /// Ad unit of [placement]; null when that placement shows no ads.
  String? unitIdFor(AdPlacement placement) => _unitIds[placement];

  /// True when at least one placement can show ads.
  bool get hasAnyUnit => _unitIds.isNotEmpty;
}
