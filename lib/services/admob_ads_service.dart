import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:chai_tapri/services/ads_config.dart';
import 'package:chai_tapri/services/ads_service.dart';

/// Optional values for trying the Google consent form on a test phone (debug builds only):
/// `--dart-define=UMP_TEST_DEVICE_ID=<hashed id from logcat>` and
/// `--dart-define=UMP_DEBUG_GEOGRAPHY=eea` (or `us`).
const String _umpTestDeviceId = String.fromEnvironment('UMP_TEST_DEVICE_ID');
const String _umpDebugGeography = String.fromEnvironment('UMP_DEBUG_GEOGRAPHY');

/// Seconds to wait before the next try after 1, 2, 3, ... failed loads.
const List<int> _retrySeconds = <int>[5, 15, 45, 120, 300];

/// A loaded rewarded ad expires after about an hour; load a fresh one before that.
const Duration _adLifetime = Duration(minutes: 50);

/// One rewarded ad that is kept ready for an ad unit. Placements that share an ad unit
/// share the slot.
class _Slot {
  _Slot(this.unitId);

  final String unitId;
  RewardedAd? ad;
  DateTime? loadedAt;
  bool loading = false;
  int failures = 0;
  Timer? retryTimer;
}

/// Rewarded ads with Google AdMob and the Google UMP consent form.
///
/// Order of events: consent information update -> consent form (only when Google says
/// it is required) -> `MobileAds.initialize()` (only when `canRequestAds()`) -> ads load
/// in the background.
class AdMobAdsService extends AdsService {
  AdMobAdsService({required AdsConfig config, DateTime Function()? now})
    : _config = config,
      _now = now ?? DateTime.now;

  final AdsConfig _config;
  final DateTime Function() _now;
  final Map<String, _Slot> _slots = <String, _Slot>{};

  Future<void>? _starting;
  bool _disposed = false;
  bool _sdkReady = false;
  bool _consentFinished = false;
  bool _consentUpdateFailed = false;
  bool _showing = false;
  bool _privacyOptionsRequired = false;

  @override
  bool get enabled {
    if (!_config.hasAnyUnit) {
      return false;
    }
    // Until the consent step is over we do not know yet, so keep the buttons visible.
    return _consentFinished ? _sdkReady : true;
  }

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> start() {
    final Future<void>? running = _starting;
    if (running != null) {
      return running;
    }
    if (_sdkReady || _disposed) {
      return Future<void>.value();
    }
    // A session that started without internet can try again later; one where the
    // consent form was already shown must not show it a second time.
    if (_consentFinished && !_consentUpdateFailed) {
      return Future<void>.value();
    }
    final Future<void> run = _run().whenComplete(() {
      _starting = null;
    });
    _starting = run;
    return run;
  }

  Future<void> _run() async {
    if (!_config.hasAnyUnit) {
      _consentFinished = true;
      _notify();
      return;
    }
    try {
      await _gatherConsent();
      await _initializeIfAllowed();
    } catch (error, stack) {
      debugPrint('Starting ads failed: $error\n$stack');
    }
    _consentFinished = true;
    _notify();
  }

  // ----------------------------------------------------------------- consent

  Future<void> _gatherConsent() async {
    final Completer<void> finished = Completer<void>();
    void finish() {
      if (!finished.isCompleted) {
        finished.complete();
      }
    }

    _consentUpdateFailed = false;
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(consentDebugSettings: _debugSettings()),
        () {
          unawaited(
            ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
              if (error != null) {
                debugPrint('Consent form: ${error.errorCode} ${error.message}');
              }
              finish();
            }).catchError((Object error) {
              debugPrint('Consent form failed: $error');
              finish();
            }),
          );
        },
        (FormError error) {
          debugPrint('Consent update failed: ${error.errorCode} ${error.message}');
          _consentUpdateFailed = true;
          finish();
        },
      );
    } catch (error) {
      debugPrint('Consent request failed: $error');
      _consentUpdateFailed = true;
      finish();
    }
    await finished.future;
    await _refreshPrivacyOptions();
  }

  ConsentDebugSettings? _debugSettings() {
    if (!kDebugMode || _umpTestDeviceId.isEmpty) {
      return null;
    }
    return ConsentDebugSettings(
      debugGeography: _umpDebugGeography == 'us'
          ? DebugGeography.debugGeographyRegulatedUsState
          : DebugGeography.debugGeographyEea,
      testIdentifiers: <String>[_umpTestDeviceId],
    );
  }

  Future<void> _refreshPrivacyOptions() async {
    try {
      final PrivacyOptionsRequirementStatus status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired = status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('Privacy options status unavailable: $error');
      _privacyOptionsRequired = false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final Completer<void> finished = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) {
          debugPrint('Privacy options: ${error.errorCode} ${error.message}');
        }
        if (!finished.isCompleted) {
          finished.complete();
        }
      });
    } catch (error) {
      debugPrint('Privacy options failed: $error');
      if (!finished.isCompleted) {
        finished.complete();
      }
    }
    await finished.future;
    await _refreshPrivacyOptions();
    await _initializeIfAllowed();
    _notify();
  }

  // --------------------------------------------------------------------- SDK

  Future<void> _initializeIfAllowed() async {
    if (_sdkReady || _disposed) {
      return;
    }
    bool allowed = false;
    try {
      allowed = await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      debugPrint('canRequestAds failed: $error');
    }
    if (!allowed) {
      return;
    }
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
    );
    await MobileAds.instance.initialize();
    _sdkReady = true;
    // The two ads that are always visible on the main screen.
    prepare(AdPlacement.boost);
    prepare(AdPlacement.freeHelper);
  }

  // ------------------------------------------------------------------- slots

  _Slot? _slotFor(AdPlacement placement) {
    final String? unitId = _config.unitIdFor(placement);
    if (unitId == null) {
      return null;
    }
    return _slots.putIfAbsent(unitId, () => _Slot(unitId));
  }

  bool _expired(_Slot slot) {
    final DateTime? loadedAt = slot.loadedAt;
    return loadedAt != null && _now().difference(loadedAt) > _adLifetime;
  }

  void _dropExpired(_Slot slot) {
    final RewardedAd? old = slot.ad;
    if (old != null && _expired(slot)) {
      slot.ad = null;
      slot.loadedAt = null;
      old.dispose();
    }
  }

  @override
  void prepare(AdPlacement placement) {
    if (!_sdkReady || _disposed) {
      return;
    }
    final _Slot? slot = _slotFor(placement);
    if (slot == null) {
      return;
    }
    _dropExpired(slot);
    _load(slot);
  }

  @override
  bool isReady(AdPlacement placement) {
    if (!_sdkReady || _disposed || _showing) {
      return false;
    }
    final _Slot? slot = _slotFor(placement);
    if (slot == null) {
      return false;
    }
    return slot.ad != null && !_expired(slot);
  }

  void _load(_Slot slot) {
    if (slot.loading || slot.ad != null || _disposed || !_sdkReady) {
      return;
    }
    slot.loading = true;
    slot.retryTimer?.cancel();
    unawaited(
      RewardedAd.load(
        adUnitId: slot.unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            slot.loading = false;
            slot.failures = 0;
            if (_disposed) {
              ad.dispose();
              return;
            }
            slot.ad = ad;
            slot.loadedAt = _now();
            _notify();
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('Rewarded ad failed to load: ${error.code} ${error.message}');
            _loadFailed(slot);
          },
        ),
      ).catchError((Object error) {
        debugPrint('Rewarded ad load crashed: $error');
        _loadFailed(slot);
      }),
    );
  }

  void _loadFailed(_Slot slot) {
    slot.loading = false;
    slot.failures += 1;
    if (_disposed) {
      return;
    }
    final int last = _retrySeconds.length - 1;
    final int index = slot.failures - 1 < last ? slot.failures - 1 : last;
    slot.retryTimer = Timer(Duration(seconds: _retrySeconds[index]), () => _load(slot));
  }

  // -------------------------------------------------------------------- show

  @override
  Future<AdOutcome> showRewarded(AdPlacement placement) async {
    if (!_sdkReady || _disposed) {
      return AdOutcome.unavailable;
    }
    final _Slot? slot = _slotFor(placement);
    if (slot == null) {
      return AdOutcome.unavailable;
    }
    if (_showing) {
      return AdOutcome.notReady;
    }
    _dropExpired(slot);
    final RewardedAd? ad = slot.ad;
    if (ad == null) {
      _load(slot);
      return AdOutcome.notReady;
    }
    slot.ad = null;
    slot.loadedAt = null;
    _showing = true;
    _notify();

    final Completer<AdOutcome> done = Completer<AdOutcome>();
    bool earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdFailedToShowFullScreenContent: (RewardedAd failedAd, AdError error) {
        debugPrint('Rewarded ad failed to show: ${error.code} ${error.message}');
        failedAd.dispose();
        if (!done.isCompleted) {
          done.complete(AdOutcome.failed);
        }
      },
      onAdDismissedFullScreenContent: (RewardedAd closedAd) {
        closedAd.dispose();
        // The "reward earned" message arrives just before the "closed" message;
        // wait a moment so a slow channel cannot make us miss it.
        Timer(const Duration(milliseconds: 250), () {
          if (!done.isCompleted) {
            done.complete(earned ? AdOutcome.rewarded : AdOutcome.dismissed);
          }
        });
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView shownAd, RewardItem reward) {
          earned = true;
        },
      );
    } catch (error) {
      debugPrint('Showing the rewarded ad failed: $error');
      ad.dispose();
      if (!done.isCompleted) {
        done.complete(AdOutcome.failed);
      }
    }
    final AdOutcome outcome = await done.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => earned ? AdOutcome.rewarded : AdOutcome.dismissed,
    );
    _showing = false;
    if (!_disposed) {
      _load(slot);
      _notify();
    }
    return outcome;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final _Slot slot in _slots.values) {
      slot.retryTimer?.cancel();
      slot.ad?.dispose();
      slot.ad = null;
    }
    super.dispose();
  }
}
