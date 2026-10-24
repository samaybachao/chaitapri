import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';

import 'package:chai_tapri/app/constants.dart';
import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/daily.dart';
import 'package:chai_tapri/core/economy.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/services/analytics.dart';
import 'package:chai_tapri/services/clock.dart';
import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/save_service.dart';

/// Result of collecting a reward (welcome back, daily reward, VIP tip).
class ClaimResult {
  const ClaimResult({required this.coins, this.outcome});

  /// Coins added to the player's purse; 0 when nothing was paid.
  final double coins;

  /// How the rewarded ad went; null when no ad was involved.
  final AdOutcome? outcome;

  bool get paid => coins > 0;
}

/// Runs the game: the 10-per-second loop, taps, purchases, offline earnings, VIP
/// customers, the tutorial, rewarded ads and saving.
///
/// The screens only listen to this object and call its methods; all rules live in
/// [GameEngine], which has no Flutter code and is covered by plain unit tests.
class GameController extends ChangeNotifier {
  GameController({
    required this.engine,
    required this.saveService,
    required this.ads,
    required this.clock,
    required this.analytics,
    required this.haptics,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       coins = ValueNotifier<double>(engine.state.coins);

  final GameEngine engine;
  final SaveService saveService;
  final AdsService ads;
  final Clock clock;
  final Analytics analytics;
  final Haptics haptics;
  final math.Random _random;

  /// The coins in the purse. Updated every tick; listen to this for the big number.
  final ValueNotifier<double> coins;

  /// How many levels the buy buttons purchase per press.
  BuyMode buyMode = BuyMode.one;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _lastMicros = 0;
  double _secondsSinceSave = 0;
  bool _started = false;
  bool _running = false;
  bool _disposed = false;

  int _signature = -1;
  int _boostSecond = 0;
  int _helperSecond = 0;
  String _dayKey = '';

  double _vipCountdown = 0;
  double _vipStayLeft = 0;
  bool _vipEngaged = false;
  double _vipOfferedTip = 0;

  GameState get state => engine.state;
  GameConfig get config => engine.config;
  Economy get economy => engine.economy;
  EconomySnapshot get snapshot => engine.snapshot;

  bool get isRunning => _running;

  // ------------------------------------------------------------------ start

  /// Call once when the app has loaded. Credits the earnings of the time the app was
  /// closed and starts the game loop.
  Future<void> start({bool runLoop = true}) async {
    if (_started) {
      return;
    }
    _started = true;
    final int now = clock.nowMs();
    final OfflineOutcome offline = engine.applyOffline(now);
    state.sessions += 1;
    _scheduleVip();
    _dayKey = todayKey;
    if (runLoop) {
      _startLoop();
    }
    _refresh(force: true);
    analytics.log('session_start', <String, Object?>{
      'session': state.sessions,
      'away_seconds': offline.awaySeconds.round(),
    });
    unawaited(ads.start());
    await saveNow();
  }

  /// Forward the app lifecycle from the widget tree.
  void handleLifecycle(AppLifecycleState lifecycle) {
    if (!_started || _disposed) {
      return;
    }
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        _enterForeground();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _enterBackground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _enterBackground() {
    if (!_running) {
      return;
    }
    _stopLoop();
    unawaited(saveNow());
  }

  void _enterForeground() {
    if (_running) {
      return;
    }
    final OfflineOutcome offline = engine.applyOffline(clock.nowMs());
    if (offline.coins > 0) {
      analytics.log('offline_earned', <String, Object?>{
        'seconds': offline.creditedSeconds.round(),
        'popup': offline.showPopup,
      });
    }
    _startLoop();
    _refresh(force: true);
    unawaited(ads.start());
  }

  // ------------------------------------------------------------- game loop

  void _startLoop() {
    if (_running || _disposed) {
      return;
    }
    _running = true;
    _stopwatch
      ..reset()
      ..start();
    _lastMicros = 0;
    _timer = Timer.periodic(
      Duration(milliseconds: (kTickSeconds * 1000).round()),
      (Timer timer) => _onTimer(),
    );
  }

  void _stopLoop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }

  void _onTimer() {
    final int micros = _stopwatch.elapsedMicroseconds;
    final double seconds = (micros - _lastMicros) / 1000000.0;
    _lastMicros = micros;
    advance(seconds);
  }

  /// Moves the game forward by [seconds] of play. The timer calls this ten times a
  /// second; tests call it directly.
  void advance(double seconds) {
    if (_disposed || !(seconds > 0)) {
      return;
    }
    final double step = seconds > kMaxTickSeconds ? kMaxTickSeconds : seconds;
    engine.tick(step);
    _tickVip(step);
    _secondsSinceSave += step;
    if (_secondsSinceSave >= kAutosaveSeconds) {
      _secondsSinceSave = 0;
      unawaited(saveNow());
    }
    _refresh();
  }

  // ---------------------------------------------------------------- saving

  /// Writes the game to disk now.
  Future<void> saveNow() async {
    state.lastSeenMs = clock.nowMs();
    await saveService.save(state);
  }

  // ------------------------------------------------------------ UI numbers

  /// Local calendar day, e.g. `2026-10-24`.
  String get todayKey => dateKey(clock.nowLocal());

  DailyInfo get dailyInfo => engine.dailyInfo(todayKey);

  bool get dailyAvailable => dailyInfo.canClaim;

  int get tutorialStep => state.tutorialStep;

  bool get boostActive => state.boostLeft > 0;

  double get boostSecondsLeft => state.boostLeft;

  bool get canAddBoost => engine.canAddBoost;

  bool get freeHelperRunning => state.freeHelperLeft > 0;

  double get freeHelperSecondsLeft => state.freeHelperLeft;

  /// True when the "free helper" offer can be taken now.
  bool get freeHelperOffered => engine.freeHelperAvailable(clock.nowMs());

  /// Seconds until the next free helper (0 when it is available or has no cooldown).
  double get freeHelperCooldownSeconds {
    final int left = state.freeHelperReadyAtMs - clock.nowMs();
    return left > 0 ? left / 1000.0 : 0.0;
  }

  bool get hasPendingOffline => state.pendingOffline > 0;

  double get pendingOfflineCoins => state.pendingOffline;

  double get pendingOfflineSeconds => state.pendingOfflineSeconds;

  bool get pendingOfflineCapped => state.pendingOfflineCapped;

  bool get vipWaiting => _vipStayLeft > 0;

  double get vipSecondsLeft => _vipStayLeft;

  // ------------------------------------------------------------------ taps

  /// One tap on the stall. Returns the coins earned.
  double tap() {
    final double earned = engine.tap();
    haptics.tap();
    if (_advanceTutorial()) {
      unawaited(saveNow());
    }
    _refresh();
    return earned;
  }

  // ------------------------------------------------------------- purchases

  void setBuyMode(BuyMode mode) {
    if (buyMode == mode) {
      return;
    }
    buyMode = mode;
    _refresh(force: true);
  }

  /// Buys levels of the upgrade at [index] in the current [buyMode].
  PurchaseResult buyUpgrade(int index) {
    final PurchaseResult result = engine.buyUpgrade(index, buyMode);
    if (result.success) {
      haptics.reward();
      _advanceTutorial();
      analytics.log('upgrade', <String, Object?>{
        'id': config.upgrades[index].id,
        'level': state.levels[index],
      });
      unawaited(saveNow());
      _refresh(force: true);
    }
    return result;
  }

  /// Unlocks the menu item at [index].
  bool unlockMenu(int index) {
    final bool done = engine.unlockMenu(index);
    if (done) {
      haptics.reward();
      analytics.log('menu_unlock', <String, Object?>{'id': config.menu[index].id});
      unawaited(saveNow());
      _refresh(force: true);
    }
    return done;
  }

  // -------------------------------------------------------------- tutorial

  /// Moves the tutorial on when the player did what the current step asked.
  /// Returns true when the step changed.
  bool _advanceTutorial() {
    bool changed = false;
    bool moved = true;
    while (moved) {
      moved = false;
      final int step = state.tutorialStep;
      if (step == 0 && state.totalTaps >= config.tutorialTapsStep1) {
        state.tutorialStep = 1;
        moved = true;
      } else if (step == 1 && _boughtAnyUpgrade) {
        state.tutorialStep = 2;
        moved = true;
      } else if (step == 2 && state.levels[economy.helperIndex] > 0) {
        state.tutorialStep = 3;
        moved = true;
      }
      changed = changed || moved;
    }
    return changed;
  }

  bool get _boughtAnyUpgrade {
    for (final int level in state.levels) {
      if (level > 0) {
        return true;
      }
    }
    return false;
  }

  /// "Skip" on the tutorial banner.
  void skipTutorial() {
    if (state.tutorialStep >= 3) {
      return;
    }
    state.tutorialStep = 3;
    unawaited(saveNow());
    _refresh(force: true);
  }

  // ------------------------------------------------------------------- ads

  /// Shows a rewarded ad. The caller pays the reward when the result is
  /// [AdOutcome.rewarded].
  Future<AdOutcome> showAd(AdPlacement placement) async {
    analytics.log('ad_request', <String, Object?>{'placement': placement.name});
    final AdOutcome outcome = await ads.showRewarded(placement);
    analytics.log('ad_result', <String, Object?>{
      'placement': placement.name,
      'outcome': outcome.name,
    });
    return outcome;
  }

  /// 2x income for 5 minutes.
  Future<AdOutcome> watchAdForBoost() async {
    if (!engine.canAddBoost) {
      return AdOutcome.unavailable;
    }
    final AdOutcome outcome = await showAd(AdPlacement.boost);
    if (outcome == AdOutcome.rewarded && !_disposed) {
      engine.grantBoost();
      haptics.reward();
      unawaited(saveNow());
      _refresh(force: true);
    }
    return outcome;
  }

  /// A free helper for a few minutes.
  Future<AdOutcome> watchAdForFreeHelper() async {
    if (!freeHelperOffered) {
      return AdOutcome.unavailable;
    }
    final AdOutcome outcome = await showAd(AdPlacement.freeHelper);
    if (outcome == AdOutcome.rewarded && !_disposed) {
      engine.grantFreeHelper(clock.nowMs());
      haptics.reward();
      unawaited(saveNow());
      _refresh(force: true);
    }
    return outcome;
  }

  // --------------------------------------------------- welcome back / daily

  /// Pays the waiting offline earnings. With [doubleWithAd] the player first watches
  /// a rewarded ad and gets twice the amount; when the ad does not complete nothing
  /// is paid and the earnings keep waiting.
  Future<ClaimResult> collectOffline({bool doubleWithAd = false}) async {
    double multiplier = 1.0;
    AdOutcome? outcome;
    if (doubleWithAd) {
      outcome = await showAd(AdPlacement.offlineDouble);
      if (outcome != AdOutcome.rewarded) {
        return ClaimResult(coins: 0, outcome: outcome);
      }
      multiplier = 2.0;
    }
    final double paid = engine.claimPendingOffline(multiplier);
    _afterClaim('offline', paid);
    return ClaimResult(coins: paid, outcome: outcome);
  }

  /// Pays today's daily reward (see [collectOffline] for [doubleWithAd]).
  Future<ClaimResult> collectDaily({bool doubleWithAd = false}) async {
    double multiplier = 1.0;
    AdOutcome? outcome;
    if (doubleWithAd) {
      outcome = await showAd(AdPlacement.dailyDouble);
      if (outcome != AdOutcome.rewarded) {
        return ClaimResult(coins: 0, outcome: outcome);
      }
      multiplier = 2.0;
    }
    final double paid = engine.claimDaily(todayKey, multiplier);
    _afterClaim('daily', paid);
    return ClaimResult(coins: paid, outcome: outcome);
  }

  // ------------------------------------------------------------------- VIP

  void _scheduleVip() {
    _vipCountdown = engine.nextVipDelay(_random);
    _vipStayLeft = 0;
    _vipEngaged = false;
  }

  void _tickVip(double seconds) {
    if (state.tutorialStep < 3) {
      return;
    }
    if (_vipStayLeft > 0) {
      if (_vipEngaged) {
        return;
      }
      _vipStayLeft -= seconds;
      if (_vipStayLeft <= 0) {
        _scheduleVip();
      }
      return;
    }
    _vipCountdown -= seconds;
    if (_vipCountdown <= 0) {
      _vipStayLeft = config.vipStaySeconds;
      _vipEngaged = false;
    }
  }

  /// The player tapped the waiting VIP customer. Returns the tip on offer, or null
  /// when no VIP is waiting. The VIP stays until the tip is collected.
  double? engageVip() {
    if (!vipWaiting) {
      return null;
    }
    _vipEngaged = true;
    _vipOfferedTip = engine.vipTip();
    return _vipOfferedTip;
  }

  /// Pays the VIP tip (see [collectOffline] for [doubleWithAd]).
  Future<ClaimResult> collectVip({bool doubleWithAd = false}) async {
    if (!_vipEngaged) {
      return const ClaimResult(coins: 0);
    }
    double multiplier = 1.0;
    AdOutcome? outcome;
    if (doubleWithAd) {
      outcome = await showAd(AdPlacement.vipDouble);
      if (outcome != AdOutcome.rewarded) {
        return ClaimResult(coins: 0, outcome: outcome);
      }
      multiplier = 2.0;
    }
    if (!_vipEngaged || _disposed) {
      return ClaimResult(coins: 0, outcome: outcome);
    }
    final double paid = _vipOfferedTip * multiplier;
    engine.addCoins(paid);
    state.vipServed += 1;
    _scheduleVip();
    _afterClaim('vip', paid);
    return ClaimResult(coins: paid, outcome: outcome);
  }

  void _afterClaim(String what, double paid) {
    if (paid > 0) {
      haptics.reward();
      analytics.log('claim', <String, Object?>{'what': what, 'coins': paid.round()});
    }
    unawaited(saveNow());
    _refresh(force: true);
  }

  // ----------------------------------------------------------------- reset

  /// Deletes all progress and starts a new game.
  Future<void> resetProgress() async {
    final int now = clock.nowMs();
    final GameState fresh = GameState.initial(config, nowMs: now);
    fresh.sessions = 1;
    fresh.lastSeenMs = now;
    state.replaceWith(fresh);
    engine.invalidate();
    _scheduleVip();
    analytics.log('reset_progress');
    _refresh(force: true);
    await saveNow();
  }

  // --------------------------------------------------------------- refresh

  /// Updates the coin display and tells the screens when something they show
  /// changed. Most ticks change nothing but the coin number.
  void _refresh({bool force = false}) {
    if (_disposed) {
      return;
    }
    coins.value = state.coins;
    final int signature = _computeSignature();
    bool changed = force || signature != _signature;
    _signature = signature;

    final int boostSecond = state.boostLeft > 0 ? state.boostLeft.ceil() : 0;
    if (boostSecond != _boostSecond) {
      _boostSecond = boostSecond;
      changed = true;
    }
    final int helperSecond = state.freeHelperLeft > 0 ? state.freeHelperLeft.ceil() : 0;
    if (helperSecond != _helperSecond) {
      _helperSecond = helperSecond;
      changed = true;
    }
    final String day = todayKey;
    if (day != _dayKey) {
      _dayKey = day;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// A number that changes whenever a yes/no thing the screens show changes
  /// (can I afford it, is the VIP here, ...).
  int _computeSignature() {
    int bits = 0;
    int bit = 0;
    for (int i = 0; i < state.levels.length; i++) {
      if (engine.canBuy(i, buyMode)) {
        bits |= 1 << bit;
      }
      bit++;
    }
    final int next = engine.nextMenuToUnlock;
    if (next >= 0 && engine.canUnlockMenu(next)) {
      bits |= 1 << bit;
    }
    bit++;
    if (engine.freeHelperAvailable(clock.nowMs())) {
      bits |= 1 << bit;
    }
    bit++;
    if (engine.canAddBoost) {
      bits |= 1 << bit;
    }
    bit++;
    if (vipWaiting) {
      bits |= 1 << bit;
    }
    bit++;
    if (hasPendingOffline) {
      bits |= 1 << bit;
    }
    bit++;
    if (engine.helperActive) {
      bits |= 1 << bit;
    }
    bit++;
    bits |= state.tutorialStep << bit;
    return bits;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLoop();
    coins.dispose();
    super.dispose();
  }
}
