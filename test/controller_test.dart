import 'dart:math' as math;
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/services/clock.dart';
import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/key_value_store.dart';
import 'package:chai_tapri/services/save_service.dart';
import 'package:chai_tapri/state/game_controller.dart';

import 'support/fakes.dart';
import 'support/test_support.dart';

/// Everything a controller test needs, with the clock and the ads under its control.
class Harness {
  Harness._({
    required this.config,
    required this.store,
    required this.clock,
    required this.ads,
    required this.analytics,
    required this.game,
  });

  final GameConfig config;
  final MemoryKeyValueStore store;
  final FakeClock clock;
  final FakeAdsService ads;
  final MemoryAnalytics analytics;
  final GameController game;

  GameState get state => game.state;
  GameEngine get engine => game.engine;
  int get helper => game.economy.helperIndex;

  static Harness create({
    GameState? state,
    FakeAdsService? ads,
    DateTime? now,
    MemoryKeyValueStore? store,
  }) {
    final GameConfig config = loadTestConfig();
    final MemoryKeyValueStore storage = store ?? MemoryKeyValueStore();
    final FakeClock clock = FakeClock(now ?? DateTime(2026, 10, 24, 12));
    final FakeAdsService fakeAds = ads ?? FakeAdsService();
    final MemoryAnalytics analytics = MemoryAnalytics();
    final GameState initial = state ?? GameState.initial(config, nowMs: clock.nowMs());
    final GameController game = GameController(
      engine: GameEngine(config: config, state: initial),
      saveService: SaveService(storage),
      ads: fakeAds,
      clock: clock,
      analytics: analytics,
      haptics: Haptics(enabled: false),
      random: math.Random(7),
    );
    return Harness._(
      config: config,
      store: storage,
      clock: clock,
      ads: fakeAds,
      analytics: analytics,
      game: game,
    );
  }

  /// Starts the game without the 10-per-second timer; tests call `advance` themselves.
  Future<void> start() => game.start(runLoop: false);

  /// Gives the player [coins] more coins.
  void give(double coins) {
    engine.addCoins(coins);
    game.advance(0.0001);
  }

  Future<void> dispose() async {
    game.dispose();
  }
}

void main() {
  silenceDebugPrint();

  group('start', () {
    test('a first launch starts a clean session', () async {
      final Harness h = Harness.create();
      await h.start();
      expect(h.state.sessions, 1);
      expect(h.game.hasPendingOffline, isFalse);
      expect(h.game.coins.value, 0);
      expect(h.game.tutorialStep, 0);
      expect(h.analytics.events, contains('session_start'));
      await Future<void>.delayed(Duration.zero);
      expect(h.ads.startCalls, 1);
      await h.dispose();
    });

    test('start is safe to call twice', () async {
      final Harness h = Harness.create();
      await h.start();
      await h.start();
      expect(h.state.sessions, 1);
      await h.dispose();
    });

    test('the first start writes a save', () async {
      final Harness h = Harness.create();
      await h.start();
      final GameState? loaded = await SaveService(h.store).load(h.config);
      expect(loaded, isNotNull);
      expect(loaded!.sessions, 1);
      await h.dispose();
    });
  });

  group('tap and tutorial', () {
    test('a tap pays coins and counts', () async {
      final Harness h = Harness.create();
      await h.start();
      final double earned = h.game.tap();
      expect(earned, greaterThan(0));
      expect(h.game.coins.value, closeTo(earned, 1e-9));
      expect(h.state.totalTaps, 1);
      await h.dispose();
    });

    test('the tutorial moves on: taps, first upgrade, helper', () async {
      final Harness h = Harness.create();
      await h.start();
      for (int i = 0; i < h.config.tutorialTapsStep1; i++) {
        expect(h.game.tutorialStep, 0);
        h.game.tap();
      }
      expect(h.game.tutorialStep, 1);

      h.give(100000);
      expect(h.game.buyUpgrade(0).success, isTrue);
      expect(h.game.tutorialStep, 2);

      expect(h.game.buyUpgrade(h.helper).success, isTrue);
      expect(h.game.tutorialStep, 3);
      await h.dispose();
    });

    test('skipTutorial finishes it and is saved', () async {
      final Harness h = Harness.create();
      await h.start();
      h.game.skipTutorial();
      expect(h.game.tutorialStep, 3);
      await Future<void>.delayed(Duration.zero);
      final GameState? loaded = await SaveService(h.store).load(h.config);
      expect(loaded!.tutorialStep, 3);
      await h.dispose();
    });
  });

  group('purchases', () {
    test('cannot buy without the coins', () async {
      final Harness h = Harness.create();
      await h.start();
      final PurchaseResult result = h.game.buyUpgrade(0);
      expect(result.success, isFalse);
      expect(h.state.levels[0], 0);
      await h.dispose();
    });

    test('buying takes the coins and raises the level', () async {
      final Harness h = Harness.create();
      await h.start();
      h.give(1000);
      final double cost = h.engine.nextCost(0);
      final PurchaseResult result = h.game.buyUpgrade(0);
      expect(result.success, isTrue);
      expect(h.state.levels[0], 1);
      expect(h.game.coins.value, closeTo(1000 - cost, 0.01));
      await h.dispose();
    });

    test('buy modes buy several levels', () async {
      final Harness h = Harness.create();
      await h.start();
      h.give(1e9);
      h.game.setBuyMode(BuyMode.ten);
      h.game.buyUpgrade(0);
      expect(h.state.levels[0], 10);
      h.game.setBuyMode(BuyMode.max);
      h.game.buyUpgrade(1);
      expect(h.state.levels[1], greaterThan(10));
      await h.dispose();
    });

    test('unlocking the next menu item', () async {
      final Harness h = Harness.create();
      await h.start();
      final double cost = h.config.menu[1].unlockCost;
      expect(h.game.unlockMenu(1), isFalse);
      h.give(cost + 1);
      expect(h.game.unlockMenu(2), isFalse, reason: 'items unlock in order');
      expect(h.game.unlockMenu(1), isTrue);
      expect(h.state.unlocked[1], isTrue);
      await h.dispose();
    });
  });

  group('notifications', () {
    test('plain income ticks only move the coin number', () async {
      final Harness h = Harness.create();
      await h.start();
      h.state.levels[h.helper] = 1;
      h.engine.invalidate();
      h.game.advance(0.1);
      int notified = 0;
      h.game.addListener(() => notified += 1);
      final double before = h.game.coins.value;
      h.game.advance(0.1);
      h.game.advance(0.1);
      expect(h.game.coins.value, greaterThan(before));
      expect(notified, 0);
      await h.dispose();
    });

    test('becoming able to afford something notifies', () async {
      final Harness h = Harness.create();
      await h.start();
      int notified = 0;
      h.game.addListener(() => notified += 1);
      h.give(h.engine.nextCost(0) + 1);
      expect(notified, greaterThan(0));
      await h.dispose();
    });
  });

  group('offline earnings', () {
    GameState sleepingState(Harness base, {required int awayMinutes}) {
      final GameState state = GameState.initial(base.config, nowMs: base.clock.nowMs());
      state.levels[base.helper] = 5;
      state.levels[0] = 5;
      state.lastSeenMs = base.clock.nowMs() - awayMinutes * 60 * 1000;
      return state;
    }

    Harness sleeping({required int awayMinutes, FakeAdsService? ads}) {
      final Harness probe = Harness.create();
      final GameState state = sleepingState(probe, awayMinutes: awayMinutes);
      return Harness.create(state: state, ads: ads, now: DateTime(2026, 10, 24, 12));
    }

    test('a long absence waits for Collect', () async {
      final Harness h = sleeping(awayMinutes: 120);
      await h.start();
      expect(h.game.hasPendingOffline, isTrue);
      final double pending = h.game.pendingOfflineCoins;
      expect(pending, greaterThan(0));
      expect(h.game.coins.value, 0);

      final ClaimResult result = await h.game.collectOffline();
      expect(result.paid, isTrue);
      expect(result.coins, closeTo(pending, 1e-9));
      expect(h.game.coins.value, closeTo(pending, 1e-9));
      expect(h.game.hasPendingOffline, isFalse);
      expect(h.ads.shown, isEmpty);
      await h.dispose();
    });

    test('Collect 2x pays double after a completed ad', () async {
      final Harness h = sleeping(awayMinutes: 120);
      await h.start();
      final double pending = h.game.pendingOfflineCoins;
      final ClaimResult result = await h.game.collectOffline(doubleWithAd: true);
      expect(result.coins, closeTo(pending * 2, 1e-9));
      expect(h.ads.shown, <AdPlacement>[AdPlacement.offlineDouble]);
      await h.dispose();
    });

    test('an ad that is closed early pays nothing and keeps the earnings', () async {
      final FakeAdsService ads = FakeAdsService()..nextOutcome = AdOutcome.dismissed;
      final Harness h = sleeping(awayMinutes: 120, ads: ads);
      await h.start();
      final double pending = h.game.pendingOfflineCoins;
      final ClaimResult result = await h.game.collectOffline(doubleWithAd: true);
      expect(result.paid, isFalse);
      expect(result.outcome, AdOutcome.dismissed);
      expect(h.game.hasPendingOffline, isTrue);
      expect(h.game.pendingOfflineCoins, closeTo(pending, 1e-9));
      expect(h.game.coins.value, 0);
      await h.dispose();
    });

    test('a short absence is paid at once, without a popup', () async {
      final Harness h = sleeping(awayMinutes: 2);
      await h.start();
      expect(h.game.hasPendingOffline, isFalse);
      expect(h.game.coins.value, greaterThan(0));
      await h.dispose();
    });

    test('coming back from the background credits the time away', () async {
      final Harness h = Harness.create();
      h.state.levels[h.helper] = 5;
      h.state.levels[0] = 5;
      h.engine.invalidate();
      await h.game.start();
      expect(h.game.isRunning, isTrue);

      h.game.handleLifecycle(AppLifecycleState.paused);
      expect(h.game.isRunning, isFalse);
      h.clock.advance(const Duration(hours: 1));
      h.game.handleLifecycle(AppLifecycleState.resumed);
      expect(h.game.isRunning, isTrue);
      expect(h.game.hasPendingOffline, isTrue);
      await h.dispose();
    });
  });

  group('daily reward', () {
    test('collect pays once per day', () async {
      final Harness h = Harness.create();
      await h.start();
      expect(h.game.dailyAvailable, isTrue);
      final double reward = h.game.dailyInfo.reward;
      final ClaimResult first = await h.game.collectDaily();
      expect(first.coins, closeTo(reward, 1e-9));
      expect(h.game.dailyAvailable, isFalse);
      final ClaimResult second = await h.game.collectDaily();
      expect(second.paid, isFalse);

      h.clock.advance(const Duration(days: 1));
      h.game.advance(0.1);
      expect(h.game.dailyAvailable, isTrue);
      expect(h.game.dailyInfo.day, 2);
      await h.dispose();
    });

    test('2x needs a completed ad', () async {
      final FakeAdsService ads = FakeAdsService()..nextOutcome = AdOutcome.failed;
      final Harness h = Harness.create(ads: ads);
      await h.start();
      final ClaimResult failed = await h.game.collectDaily(doubleWithAd: true);
      expect(failed.paid, isFalse);
      expect(h.game.dailyAvailable, isTrue);

      ads.nextOutcome = AdOutcome.rewarded;
      final double reward = h.game.dailyInfo.reward;
      final ClaimResult doubled = await h.game.collectDaily(doubleWithAd: true);
      expect(doubled.coins, closeTo(reward * 2, 1e-9));
      expect(h.game.dailyAvailable, isFalse);
      await h.dispose();
    });
  });

  group('boost and free helper', () {
    test('a watched ad starts the boost and it can stack up to the limit', () async {
      final Harness h = Harness.create();
      await h.start();
      expect(h.game.boostActive, isFalse);
      expect(await h.game.watchAdForBoost(), AdOutcome.rewarded);
      expect(h.game.boostActive, isTrue);
      expect(h.game.boostSecondsLeft, h.config.boostDurationSeconds);

      while (h.game.canAddBoost) {
        await h.game.watchAdForBoost();
      }
      expect(h.game.boostSecondsLeft, lessThanOrEqualTo(h.config.boostMaxStackSeconds));
      final int shownBefore = h.ads.shown.length;
      expect(await h.game.watchAdForBoost(), AdOutcome.unavailable);
      expect(h.ads.shown.length, shownBefore, reason: 'no ad when the stack is full');
      await h.dispose();
    });

    test('a closed ad gives no boost', () async {
      final FakeAdsService ads = FakeAdsService()..nextOutcome = AdOutcome.dismissed;
      final Harness h = Harness.create(ads: ads);
      await h.start();
      expect(await h.game.watchAdForBoost(), AdOutcome.dismissed);
      expect(h.game.boostActive, isFalse);
      await h.dispose();
    });

    test('the boost doubles the income and runs down', () async {
      final Harness h = Harness.create();
      await h.start();
      h.state.levels[h.helper] = 3;
      h.engine.invalidate();
      final double rate = h.game.snapshot.idleRate;
      final double before = h.game.coins.value;
      h.game.advance(1);
      final double normal = h.game.coins.value - before;
      expect(normal, closeTo(rate, rate * 0.001));

      await h.game.watchAdForBoost();
      final double mark = h.game.coins.value;
      h.game.advance(1);
      expect(h.game.coins.value - mark, closeTo(rate * h.config.boostMultiplier, rate * 0.01));
      await h.dispose();
    });

    test('the free helper runs, then waits for the cooldown', () async {
      final Harness h = Harness.create();
      await h.start();
      expect(h.game.freeHelperOffered, isTrue);
      expect(await h.game.watchAdForFreeHelper(), AdOutcome.rewarded);
      expect(h.game.freeHelperRunning, isTrue);
      expect(h.game.freeHelperOffered, isFalse);
      expect(h.game.freeHelperCooldownSeconds, greaterThan(0));
      expect(await h.game.watchAdForFreeHelper(), AdOutcome.unavailable);

      final int seconds = h.config.freeHelperSeconds.ceil() + 1;
      for (int i = 0; i < seconds; i++) {
        h.game.advance(1);
      }
      expect(h.game.freeHelperRunning, isFalse);

      h.clock.advance(Duration(seconds: h.config.freeHelperCooldownSeconds.ceil() + 1));
      expect(h.game.freeHelperOffered, isTrue);
      await h.dispose();
    });

    test('a bought helper replaces the free one', () async {
      final Harness h = Harness.create();
      await h.start();
      h.give(1e9);
      h.game.buyUpgrade(h.helper);
      expect(h.game.freeHelperOffered, isFalse);
      expect(await h.game.watchAdForFreeHelper(), AdOutcome.unavailable);
      await h.dispose();
    });
  });

  group('VIP customer', () {
    Future<Harness> readyForVip() async {
      final Harness h = Harness.create();
      await h.start();
      h.game.skipTutorial();
      return h;
    }

    void waitForVip(Harness h) {
      final int limit = h.config.vipMaxGapSeconds.ceil() + 5;
      for (int i = 0; i < limit && !h.game.vipWaiting; i++) {
        h.game.advance(1);
      }
    }

    test('no VIP during the tutorial', () async {
      final Harness h = Harness.create();
      await h.start();
      for (int i = 0; i < 400; i++) {
        h.game.advance(1);
      }
      expect(h.game.vipWaiting, isFalse);
      await h.dispose();
    });

    test('a VIP shows up, is engaged and pays the tip', () async {
      final Harness h = await readyForVip();
      waitForVip(h);
      expect(h.game.vipWaiting, isTrue);

      final double? tip = h.game.engageVip();
      expect(tip, isNotNull);
      expect(tip, closeTo(h.engine.vipTip(), 1e-9));

      final double before = h.game.coins.value;
      final ClaimResult result = await h.game.collectVip();
      expect(result.coins, closeTo(tip!, 1e-9));
      expect(h.game.coins.value, closeTo(before + tip, 1e-6));
      expect(h.game.vipWaiting, isFalse);
      expect(h.state.vipServed, 1);
      await h.dispose();
    });

    test('Collect 2x doubles the tip', () async {
      final Harness h = await readyForVip();
      waitForVip(h);
      final double tip = h.game.engageVip() ?? 0;
      final ClaimResult result = await h.game.collectVip(doubleWithAd: true);
      expect(result.coins, closeTo(tip * 2, 1e-9));
      expect(h.ads.shown, <AdPlacement>[AdPlacement.vipDouble]);
      await h.dispose();
    });

    test('an engaged VIP waits while the dialog is open', () async {
      final Harness h = await readyForVip();
      waitForVip(h);
      h.game.engageVip();
      for (int i = 0; i < h.config.vipStaySeconds.ceil() * 3; i++) {
        h.game.advance(1);
      }
      expect(h.game.vipWaiting, isTrue);
      await h.dispose();
    });

    test('an ignored VIP leaves', () async {
      final Harness h = await readyForVip();
      waitForVip(h);
      expect(h.game.vipWaiting, isTrue);
      for (int i = 0; i < h.config.vipStaySeconds.ceil() + 2; i++) {
        h.game.advance(1);
      }
      expect(h.game.vipWaiting, isFalse);
      expect(h.state.vipServed, 0);
      await h.dispose();
    });

    test('collecting without a VIP pays nothing', () async {
      final Harness h = await readyForVip();
      expect(h.game.engageVip(), isNull);
      final ClaimResult result = await h.game.collectVip();
      expect(result.paid, isFalse);
      await h.dispose();
    });
  });

  group('saving', () {
    test('saveNow stores the progress', () async {
      final Harness h = Harness.create();
      await h.start();
      h.give(5000);
      h.game.buyUpgrade(0);
      await h.game.saveNow();
      final GameState? loaded = await SaveService(h.store).load(h.config);
      expect(loaded, isNotNull);
      expect(loaded!.levels[0], 1);
      expect(loaded.coins, closeTo(h.state.coins, 1e-6));
      await h.dispose();
    });

    test('a new controller continues where the old one stopped', () async {
      final Harness first = Harness.create();
      await first.start();
      first.give(5000);
      first.game.buyUpgrade(0);
      await first.game.saveNow();
      final MemoryKeyValueStore store = first.store;
      await first.dispose();

      final GameState? loaded = await SaveService(store).load(first.config);
      final Harness second = Harness.create(state: loaded, store: store);
      await second.start();
      expect(second.state.levels[0], 1);
      expect(second.state.sessions, 2);
      await second.dispose();
    });

    test('autosave writes while playing', () async {
      final Harness h = Harness.create();
      await h.start();
      h.state.coins = 123;
      for (int i = 0; i < 12; i++) {
        h.game.advance(1);
      }
      await Future<void>.delayed(Duration.zero);
      final GameState? loaded = await SaveService(h.store).load(h.config);
      expect(loaded!.coins, greaterThanOrEqualTo(123));
      await h.dispose();
    });
  });

  group('reset', () {
    test('reset deletes the progress and keeps the game running', () async {
      final Harness h = Harness.create();
      await h.start();
      h.give(1e6);
      h.game.buyUpgrade(0);
      h.game.skipTutorial();
      await h.game.resetProgress();

      expect(h.state.levels.every((int level) => level == 0), isTrue);
      expect(h.game.coins.value, 0);
      expect(h.game.tutorialStep, 0);
      expect(h.state.sessions, 1);
      expect(h.state.unlocked.where((bool open) => open).length, 1);

      final GameState? loaded = await SaveService(h.store).load(h.config);
      expect(loaded!.levels.every((int level) => level == 0), isTrue);
      await h.dispose();
    });
  });
}
