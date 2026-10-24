import 'package:flutter/foundation.dart';

/// The places where the game offers a rewarded ad. Each one can have its own AdMob
/// ad unit (see `AdsConfig`), which makes the AdMob reports easy to read.
enum AdPlacement {
  /// 2x income for 5 minutes (top bar).
  boost,

  /// A free helper for 10 minutes (before the real helper is bought).
  freeHelper,

  /// Welcome-back popup: double the offline earnings.
  offlineDouble,

  /// VIP customer popup: double the tip.
  vipDouble,

  /// Daily reward: double the coins.
  dailyDouble,
}

/// What happened when the player asked for a rewarded ad.
enum AdOutcome {
  /// The player watched the ad: give the reward.
  rewarded,

  /// The player closed the ad early: no reward.
  dismissed,

  /// No ad is loaded yet: try again in a moment.
  notReady,

  /// Ads are switched off (no consent, no ad unit, unsupported device).
  unavailable,

  /// The ad could not be shown.
  failed,
}

/// Rewarded ads. The game only talks to this interface, so tests (and builds without
/// ads) can use `NoAdsService` or a fake.
abstract class AdsService extends ChangeNotifier {
  /// False when ads can never be shown in this session; the UI then hides the ad
  /// buttons. It stays true while the SDK is still starting up.
  bool get enabled;

  /// True when Settings must offer the "Privacy options" entry (Google consent
  /// message in the EEA, UK and some US states).
  bool get privacyOptionsRequired;

  /// Asks for consent when it is required and starts the ads SDK. Safe to call twice.
  Future<void> start();

  /// Starts loading the ad of [placement] when none is loaded.
  void prepare(AdPlacement placement);

  /// True when [showRewarded] would show an ad right now.
  bool isReady(AdPlacement placement);

  /// Shows a rewarded ad and completes when it is closed.
  Future<AdOutcome> showRewarded(AdPlacement placement);

  /// Opens Google's consent options again (only when [privacyOptionsRequired]).
  Future<void> showPrivacyOptions();
}

/// Ads are off. Used for tests and when no ad unit is configured.
class NoAdsService extends AdsService {
  NoAdsService();

  @override
  bool get enabled => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> start() async {}

  @override
  void prepare(AdPlacement placement) {}

  @override
  bool isReady(AdPlacement placement) => false;

  @override
  Future<AdOutcome> showRewarded(AdPlacement placement) async => AdOutcome.unavailable;

  @override
  Future<void> showPrivacyOptions() async {}
}
