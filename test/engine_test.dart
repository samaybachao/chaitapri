import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/engine.dart';

import 'support/test_support.dart';

Matcher near(double expected) {
  final double relative = expected.abs() * 1e-9;
  return closeTo(expected, relative > 1e-6 ? relative : 1e-6);
}

/// Upgrade levels used by several tests: the "S1" early-game state of the economy tests.
const List<int> _s1Levels = <int>[10, 8, 6, 4, 5, 3];

void main() {
  late GameConfig config;
  late GameEngine engine;

  setUp(() {
    config = loadTestConfig();
    engine = newEngine(config: config);
  });

  int index(String id) => config.upgradeIndex(id);

  void giveS1() {
    setLevels(engine, _s1Levels);
    unlockFirst(engine, 2);
  }

  group('coins', () {
    test('addCoins ignores nonsense', () {
      engine.addCoins(double.nan);
      engine.addCoins(double.infinity);
      engine.addCoins(-5);
      engine.addCoins(0);
      expect(engine.state.coins, 0);
      engine.addCoins(12.5);
      expect(engine.state.coins, 12.5);
      expect(engine.state.lifetimeCoins, 12.5);
    });
  });

  group('tap', () {
    test('pays the tap income and counts the tap', () {
      final double earned = engine.tap();
      expect(earned, near(3.227891794394833));
      expect(engine.state.coins, near(3.227891794394833));
      expect(engine.state.totalTaps, 1);
    });

    test('pays double during a boost', () {
      engine.state.boostLeft = 10;
      expect(engine.tap(), near(2 * 3.227891794394833));
    });
  });

  group('tick', () {
    test('earns nothing without a helper', () {
      expect(engine.tick(10), 0);
      expect(engine.state.coins, 0);
    });

    test('earns the idle rate with a helper', () {
      giveS1();
      final double gained = engine.tick(2);
      expect(gained, near(2 * 6.337731852266973));
      expect(engine.state.coins, near(2 * 6.337731852266973));
    });

    test('ignores zero, negative and NaN time', () {
      giveS1();
      expect(engine.tick(0), 0);
      expect(engine.tick(-1), 0);
      expect(engine.tick(double.nan), 0);
      expect(engine.state.coins, 0);
    });

    test('boost doubles the income and counts down', () {
      giveS1();
      engine.state.boostLeft = 5;
      final double gained = engine.tick(2);
      expect(gained, near(2 * 2 * 6.337731852266973));
      expect(engine.state.boostLeft, near(3));
      engine.tick(10);
      expect(engine.state.boostLeft, 0);
      expect(engine.boostMultiplier, 1.0);
    });

    test('the free helper works for its time and then stops', () {
      expect(engine.helperActive, isFalse);
      engine.grantFreeHelper(1000);
      expect(engine.helperActive, isTrue);
      expect(engine.tick(10), near(10 * 0.6065764953290278));
      engine.tick(config.freeHelperSeconds);
      expect(engine.state.freeHelperLeft, 0);
      expect(engine.helperActive, isFalse);
      expect(engine.tick(10), 0);
    });
  });

  group('upgrades', () {
    test('cannot be bought without enough coins', () {
      engine.state.coins = 169;
      expect(engine.canBuy(index('chulha'), BuyMode.one), isFalse);
      final PurchaseResult result = engine.buyUpgrade(index('chulha'), BuyMode.one);
      expect(result.success, isFalse);
      expect(engine.state.levels[index('chulha')], 0);
      expect(engine.state.coins, 169);
    });

    test('buying one level spends exactly the price', () {
      engine.state.coins = 200;
      final PurchaseResult result = engine.buyUpgrade(index('chulha'), BuyMode.one);
      expect(result.count, 1);
      expect(result.cost, 170);
      expect(engine.state.coins, 30);
      expect(engine.state.levels[index('chulha')], 1);
    });

    test('a purchase refreshes the income numbers', () {
      engine.state.coins = 1000;
      final double before = engine.snapshot.brewRate;
      engine.buyUpgrade(index('chulha'), BuyMode.one);
      expect(engine.snapshot.brewRate, greaterThan(before));
    });

    test('buy x10 needs the full price of ten levels', () {
      final int chulha = index('chulha');
      engine.state.coins = 6000;
      expect(engine.plannedCount(chulha, BuyMode.ten), 10);
      expect(engine.canBuy(chulha, BuyMode.ten), isFalse);
      engine.state.coins = 6100;
      expect(engine.canBuy(chulha, BuyMode.ten), isTrue);
      final PurchaseResult result = engine.buyUpgrade(chulha, BuyMode.ten);
      expect(result.count, 10);
      expect(result.cost, closeTo(6096, 2));
      expect(engine.state.levels[chulha], 10);
    });

    test('buy max spends what it can', () {
      final int chulha = index('chulha');
      engine.state.coins = 1000;
      expect(engine.plannedCount(chulha, BuyMode.max), 3);
      final PurchaseResult result = engine.buyUpgrade(chulha, BuyMode.max);
      expect(result.count, 3);
      expect(engine.state.levels[chulha], 3);
      expect(engine.state.coins, greaterThanOrEqualTo(0));
      expect(engine.state.coins, lessThan(engine.nextCost(chulha)));
    });

    test('buy max with too few coins plans one level to show a price', () {
      engine.state.coins = 5;
      expect(engine.plannedCount(index('chulha'), BuyMode.max), 1);
      expect(engine.canBuy(index('chulha'), BuyMode.max), isFalse);
    });

    test('stops at the level cap', () {
      final int chulha = index('chulha');
      engine.state.levels[chulha] = config.maxLevel - 2;
      engine.state.coins = 1e30;
      expect(engine.plannedCount(chulha, BuyMode.ten), 2);
      expect(engine.buyUpgrade(chulha, BuyMode.ten).count, 2);
      expect(engine.state.levels[chulha], config.maxLevel);
      expect(engine.nextCost(chulha), 0);
      expect(engine.plannedCount(chulha, BuyMode.one), 0);
      expect(engine.canBuy(chulha, BuyMode.max), isFalse);
      expect(engine.buyUpgrade(chulha, BuyMode.one).success, isFalse);
    });
  });

  group('menu', () {
    test('unlocks in order and charges the price', () {
      expect(engine.nextMenuToUnlock, 1);
      expect(engine.canUnlockMenu(2), isFalse);
      engine.state.coins = 2000;
      expect(engine.canUnlockMenu(2), isFalse, reason: 'cannot skip masala');
      expect(engine.unlockMenu(2), isFalse);
      expect(engine.unlockMenu(1), isTrue);
      expect(engine.state.coins, 250);
      expect(engine.state.unlocked, <bool>[true, true, false, false]);
      expect(engine.nextMenuToUnlock, 2);
    });

    test('needs enough coins', () {
      engine.state.coins = 1749;
      expect(engine.unlockMenu(1), isFalse);
      expect(engine.state.unlocked[1], isFalse);
      expect(engine.state.coins, 1749);
    });

    test('everything unlocked: nothing left to unlock', () {
      unlockFirst(engine, 4);
      expect(engine.nextMenuToUnlock, -1);
      expect(engine.unlockMenu(3), isFalse);
    });

    test('a new item changes the income', () {
      setLevels(engine, <int>[10, 10, 10, 1, 10, 0]);
      final double before = engine.snapshot.avgPrice;
      engine.state.coins = 5000;
      engine.unlockMenu(1);
      expect(engine.snapshot.avgPrice, greaterThan(before));
    });
  });

  group('offline earnings', () {
    const int hour = 3600 * 1000;

    test('the first launch earns nothing and starts the clock', () {
      giveS1();
      final OfflineOutcome outcome = engine.applyOffline(5000000);
      expect(outcome.coins, 0);
      expect(outcome.showPopup, isFalse);
      expect(engine.state.lastSeenMs, 5000000);
      expect(engine.state.coins, 0);
    });

    test('a clock that moved backwards earns nothing', () {
      giveS1();
      engine.state.lastSeenMs = 10 * hour;
      final OfflineOutcome outcome = engine.applyOffline(5 * hour);
      expect(outcome.coins, 0);
      expect(engine.state.lastSeenMs, 5 * hour);
      expect(engine.state.pendingOffline, 0);
    });

    test('one hour away is held for the welcome-back popup', () {
      giveS1();
      engine.state.lastSeenMs = 1000;
      final OfflineOutcome outcome = engine.applyOffline(1000 + hour);
      expect(outcome.showPopup, isTrue);
      expect(outcome.capped, isFalse);
      expect(outcome.coins, near(11407.917334080552));
      expect(engine.state.pendingOffline, near(11407.917334080552));
      expect(engine.state.pendingOfflineSeconds, near(3600));
      expect(engine.state.coins, 0, reason: 'waits for the Collect button');
    });

    test('the cap is three hours', () {
      giveS1();
      engine.state.lastSeenMs = 1000;
      final OfflineOutcome outcome = engine.applyOffline(1000 + 10 * hour);
      expect(outcome.capped, isTrue);
      expect(outcome.awaySeconds, near(36000));
      expect(outcome.creditedSeconds, near(10800));
      expect(outcome.coins, near(34223.75200224166));
      expect(engine.state.pendingOfflineCapped, isTrue);
    });

    test('a short absence is credited silently', () {
      giveS1();
      engine.state.lastSeenMs = 1000;
      final OfflineOutcome outcome = engine.applyOffline(1000 + 120 * 1000);
      expect(outcome.showPopup, isFalse);
      expect(outcome.coins, greaterThan(0));
      expect(engine.state.coins, near(outcome.coins));
      expect(engine.state.pendingOffline, 0);
    });

    test('without a bought helper nothing is earned', () {
      engine.state.lastSeenMs = 1000;
      final OfflineOutcome outcome = engine.applyOffline(1000 + hour);
      expect(outcome.coins, 0);
      expect(outcome.showPopup, isFalse);
      expect(engine.state.pendingOffline, 0);
    });

    test('the free ad helper does not work while the app is closed', () {
      engine.grantFreeHelper(0);
      engine.state.lastSeenMs = 1000;
      final OfflineOutcome outcome = engine.applyOffline(1000 + hour);
      expect(outcome.coins, 0);
    });

    test('collecting pays once, double after an ad', () {
      giveS1();
      engine.state.lastSeenMs = 1000;
      engine.applyOffline(1000 + hour);
      final double paid = engine.claimPendingOffline(2.0);
      expect(paid, near(2 * 11407.917334080552));
      expect(engine.state.coins, near(paid));
      expect(engine.state.pendingOffline, 0);
      expect(engine.state.pendingOfflineCapped, isFalse);
      expect(engine.claimPendingOffline(1.0), 0, reason: 'cannot be claimed twice');
    });

    test('two absences before collecting add up', () {
      giveS1();
      engine.state.lastSeenMs = 1000;
      engine.applyOffline(1000 + hour);
      engine.applyOffline(1000 + 2 * hour);
      expect(engine.state.pendingOffline, near(2 * 11407.917334080552));
    });
  });

  group('daily reward', () {
    test('day 1 pays at least the minimum', () {
      final DailyInfo info = engine.dailyInfo('2026-10-22');
      expect(info.canClaim, isTrue);
      expect(info.day, 1);
      expect(info.claimedThrough, 0);
      expect(info.reward, near(363.9458971974167));
    });

    test('pays by income once the stall earns', () {
      giveS1();
      expect(engine.dailyReward(1), near(3802.639111360184));
      expect(engine.dailyReward(2), near(5703.958667040276));
      expect(engine.dailyReward(7), near(45631.66933632221));
      expect(engine.dailyReward(0), near(3802.639111360184), reason: 'out of range -> day 1');
      expect(engine.dailyReward(9), near(45631.66933632221), reason: 'out of range -> day 7');
    });

    test('the minimum protects a tiny stall', () {
      final GameConfig generous = loadTestConfigWith((Map<String, dynamic> json) {
        (json['daily'] as Map<String, dynamic>)['minCoins'] = 5000;
      });
      final GameEngine small = newEngine(config: generous);
      expect(small.dailyReward(1), 5000);
      expect(small.dailyReward(7), 5000);
    });

    test('can be claimed once a day', () {
      giveS1();
      final double paid = engine.claimDaily('2026-10-22', 1.0);
      expect(paid, near(3802.639111360184));
      expect(engine.state.coins, near(paid));
      expect(engine.state.dailyStreak, 1);
      expect(engine.state.lastDailyDate, '2026-10-22');
      expect(engine.dailyInfo('2026-10-22').canClaim, isFalse);
      expect(engine.dailyInfo('2026-10-22').claimedThrough, 1);
      expect(engine.claimDaily('2026-10-22', 1.0), 0);
    });

    test('an ad doubles it', () {
      giveS1();
      expect(engine.claimDaily('2026-10-22', 2.0), near(2 * 3802.639111360184));
    });

    test('the next day continues the streak', () {
      giveS1();
      engine.claimDaily('2026-10-22', 1.0);
      final DailyInfo info = engine.dailyInfo('2026-10-23');
      expect(info.canClaim, isTrue);
      expect(info.day, 2);
      expect(info.claimedThrough, 1);
      engine.claimDaily('2026-10-23', 1.0);
      expect(engine.state.dailyStreak, 2);
    });

    test('a missed day restarts the cycle', () {
      giveS1();
      engine.claimDaily('2026-10-22', 1.0);
      engine.claimDaily('2026-10-23', 1.0);
      final DailyInfo info = engine.dailyInfo('2026-10-25');
      expect(info.canClaim, isTrue);
      expect(info.day, 1);
      expect(info.claimedThrough, 0);
    });

    test('after day 7 the cycle starts again', () {
      giveS1();
      final List<String> days = <String>[
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
        '2026-10-04',
        '2026-10-05',
        '2026-10-06',
        '2026-10-07',
      ];
      for (final String day in days) {
        expect(engine.claimDaily(day, 1.0), greaterThan(0));
      }
      expect(engine.state.dailyStreak, 7);
      final DailyInfo info = engine.dailyInfo('2026-10-08');
      expect(info.canClaim, isTrue);
      expect(info.day, 1);
    });

    test('a clock set back cannot claim again', () {
      giveS1();
      engine.claimDaily('2026-10-22', 1.0);
      expect(engine.dailyInfo('2026-10-20').canClaim, isFalse);
      expect(engine.claimDaily('2026-10-20', 1.0), 0);
    });

    test('works across month and year boundaries', () {
      giveS1();
      engine.claimDaily('2026-12-31', 1.0);
      final DailyInfo info = engine.dailyInfo('2027-01-01');
      expect(info.canClaim, isTrue);
      expect(info.day, 2);
    });
  });

  group('VIP customers', () {
    test('the tip follows the helper-run income and the radio', () {
      giveS1();
      expect(engine.vipTip(), near(403.07974580417954));
    });

    test('the delay stays inside the gap', () {
      final math.Random random = math.Random(42);
      for (int i = 0; i < 500; i++) {
        final double delay = engine.nextVipDelay(random);
        expect(delay, greaterThanOrEqualTo(config.vipMinGapSeconds));
        expect(delay, lessThanOrEqualTo(config.vipMaxGapSeconds));
      }
    });

    test('a high radio level shortens the longest wait', () {
      engine.state.levels[index('radio')] = 50;
      engine.invalidate();
      final math.Random random = math.Random(7);
      for (int i = 0; i < 500; i++) {
        expect(engine.nextVipDelay(random), lessThanOrEqualTo(240.0 + 1e-9));
      }
    });
  });

  group('boost', () {
    test('adds five minutes up to the stacking limit', () {
      expect(engine.canAddBoost, isTrue);
      engine.grantBoost();
      expect(engine.state.boostLeft, 300);
      engine.grantBoost();
      engine.grantBoost();
      expect(engine.state.boostLeft, 900);
      expect(engine.canAddBoost, isTrue);
      engine.grantBoost();
      expect(engine.state.boostLeft, 1200);
      expect(engine.canAddBoost, isFalse);
      engine.grantBoost();
      expect(engine.state.boostLeft, 1200, reason: 'never above the limit');
    });

    test('a partly used boost can still be extended', () {
      engine.state.boostLeft = 950;
      expect(engine.canAddBoost, isFalse);
      engine.state.boostLeft = 900;
      expect(engine.canAddBoost, isTrue);
    });
  });

  group('free helper', () {
    test('is offered to a stall without a bought helper', () {
      expect(engine.freeHelperAvailable(0), isTrue);
    });

    test('has a cooldown measured from the moment it was granted', () {
      engine.grantFreeHelper(1000000);
      expect(engine.state.freeHelperLeft, config.freeHelperSeconds);
      expect(engine.state.freeHelperReadyAtMs, 1000000 + 1800 * 1000);
      expect(engine.freeHelperAvailable(1000000 + 10), isFalse, reason: 'still running');
      engine.state.freeHelperLeft = 0;
      expect(engine.freeHelperAvailable(1000000 + 1000 * 1000), isFalse, reason: 'cooldown');
      expect(engine.freeHelperAvailable(1000000 + 1800 * 1000), isTrue);
    });

    test('is not offered once the helper was bought', () {
      engine.state.levels[index('helper')] = 1;
      engine.invalidate();
      expect(engine.freeHelperAvailable(0), isFalse);
    });
  });
}
