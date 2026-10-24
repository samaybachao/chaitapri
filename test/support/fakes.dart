import 'package:flutter/foundation.dart';

import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/services/analytics.dart';
import 'package:chai_tapri/services/links.dart';

/// Remembers the logged events.
class MemoryAnalytics implements Analytics {
  final List<String> events = <String>[];

  @override
  void log(String event, [Map<String, Object?> parameters = const <String, Object?>{}]) {
    events.add(event);
  }
}

/// Remembers the opened links.
class FakeLinks extends LinkOpener {
  final List<String> opened = <String>[];

  /// Links that "cannot be opened" (to test fallbacks): matched by prefix.
  final Set<String> blocked = <String>{};

  @override
  Future<bool> open(String url) async {
    if (blocked.any(url.startsWith)) {
      return false;
    }
    opened.add(url);
    return true;
  }
}

/// Ads that the test controls.
class FakeAdsService extends AdsService {
  FakeAdsService({this.isEnabled = true, this.ready = true});

  bool isEnabled;

  /// Whether `isReady` answers true.
  bool ready;

  /// What the next `showRewarded` returns.
  AdOutcome nextOutcome = AdOutcome.rewarded;

  /// Placements that were shown.
  final List<AdPlacement> shown = <AdPlacement>[];

  bool privacyRequired = false;
  int privacyOptionsShown = 0;
  int startCalls = 0;

  @override
  bool get enabled => isEnabled;

  @override
  bool get privacyOptionsRequired => privacyRequired;

  @override
  Future<void> start() async {
    startCalls += 1;
  }

  @override
  void prepare(AdPlacement placement) {}

  @override
  bool isReady(AdPlacement placement) => isEnabled && ready;

  @override
  Future<AdOutcome> showRewarded(AdPlacement placement) async {
    if (!isEnabled) {
      return AdOutcome.unavailable;
    }
    shown.add(placement);
    return nextOutcome;
  }

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionsShown += 1;
    notifyListeners();
  }

  /// Changes readiness and tells the listeners (like a real load would).
  void setReady(bool value) {
    ready = value;
    notifyListeners();
  }
}

/// Used by tests that need to see `debugPrint` output silenced.
void silenceDebugPrint() {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
