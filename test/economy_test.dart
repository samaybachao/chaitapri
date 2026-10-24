import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/economy.dart';

import 'support/test_support.dart';

/// Golden values come from `tool/simulate_economy.py`, which implements the same
/// formulas. If a number here changes, change the Python mirror too.
Matcher near(double expected) {
  final double relative = expected.abs() * 1e-9;
  return closeTo(expected, relative > 1e-6 ? relative : 1e-6);
}

void main() {
  late GameConfig config;
  late Economy economy;

  setUp(() {
    config = loadTestConfig();
    economy = Economy(config);
  });

  int index(String id) => config.upgradeIndex(id);

  group('levelMult', () {
    test('is linear until the first milestone', () {
      expect(economy.levelMult(index('chulha'), 0), near(1.0));
      expect(economy.levelMult(index('chulha'), 1), near(1.2));
      expect(economy.levelMult(index('chulha'), 24), near(5.8));
    });

    test('doubles at the milestones', () {
      expect(economy.levelMult(index('chulha'), 25), near(12.0));
      expect(economy.levelMult(index('chulha'), 49), near(21.6));
      expect(economy.levelMult(index('chulha'), 50), near(44.0));
      expect(economy.levelMult(index('kettle'), 24), near(7.0));
      expect(economy.levelMult(index('kettle'), 25), near(14.5));
      expect(economy.levelMult(index('kettle'), 50), near(54.0));
    });

    test('never decreases when a level is added', () {
      for (final UpgradeDef def in config.upgrades) {
        final int i = config.upgradeIndex(def.id);
        double previous = 0;
        for (int level = 0; level <= config.maxLevel; level++) {
          final double value = economy.levelMult(i, level);
          expect(value, greaterThanOrEqualTo(previous), reason: '${def.id} level $level');
          previous = value;
        }
      }
    });
  });

  group('costs', () {
    test('match the simulator', () {
      expect(economy.upgradeCost(index('chulha'), 0), 170);
      expect(economy.upgradeCost(index('chulha'), 1), 216);
      expect(economy.upgradeCost(index('chulha'), 2), 273);
      expect(economy.upgradeCost(index('chulha'), 10), closeTo(1784, 1));
      expect(economy.upgradeCost(index('chulha'), 25), closeTo(60634, 1));
      expect(economy.upgradeCost(index('chulha'), 49), closeTo(17095613, 2));
      expect(economy.upgradeCost(index('helper'), 0), 1150);
      expect(economy.upgradeCost(index('helper'), 1), 1467);
      expect(economy.upgradeCost(index('helper'), 10), closeTo(13056, 1));
      expect(economy.upgradeCost(index('helper'), 49), closeTo(170097095, 3));
      expect(economy.upgradeCost(index('kettle'), 0), 340);
      expect(economy.upgradeCost(index('kettle'), 5), closeTo(1102, 1));
      expect(economy.upgradeCost(index('kettle'), 20), closeTo(37436, 1));
    });

    test('are whole numbers that grow with every level', () {
      for (final UpgradeDef def in config.upgrades) {
        final int i = config.upgradeIndex(def.id);
        double previous = 0;
        for (int level = 0; level < config.maxLevel; level++) {
          final double cost = economy.upgradeCost(i, level);
          expect(cost, cost.floorToDouble(), reason: '${def.id} level $level is not whole');
          expect(cost, greaterThan(previous), reason: '${def.id} level $level');
          previous = cost;
        }
      }
    });

    test('bulkCost adds the single prices', () {
      expect(economy.bulkCost(index('chulha'), 0, 10), closeTo(6096, 2));
      expect(economy.bulkCost(index('kettle'), 5, 3), closeTo(4259, 2));
      expect(economy.bulkCost(index('chulha'), 3, 0), 0);
      double manual = 0;
      for (int level = 7; level < 12; level++) {
        manual += economy.upgradeCost(index('seats'), level);
      }
      expect(economy.bulkCost(index('seats'), 7, 5), manual);
    });

    test('maxAffordable never overspends and respects the level cap', () {
      final int chulha = index('chulha');
      expect(economy.maxAffordable(chulha, 0, 1000), 3);
      expect(economy.maxAffordable(chulha, 0, 100), 0);
      expect(economy.maxAffordable(chulha, 0, 1e30), config.maxLevel);
      expect(economy.maxAffordable(chulha, 45, 1e30), 5);
      expect(economy.maxAffordable(chulha, config.maxLevel, 1e30), 0);
      for (final double coins in <double>[0, 169, 170, 385, 386, 5000, 123456]) {
        final int count = economy.maxAffordable(chulha, 0, coins);
        expect(economy.bulkCost(chulha, 0, count), lessThanOrEqualTo(coins));
        if (count < config.maxLevel) {
          expect(economy.bulkCost(chulha, 0, count + 1), greaterThan(coins));
        }
      }
    });
  });

  group('menu', () {
    test('only the newest item gets the order bonus', () {
      expect(economy.menuWeights(<bool>[true, false, false, false]), <double>[4, 0, 0, 0]);
      expect(economy.menuWeights(<bool>[true, true, false, false]), <double>[4, 6, 0, 0]);
      expect(economy.menuWeights(<bool>[true, true, true, true]), <double>[4, 3, 2.5, 4]);
    });

    test('brew time follows the chulha speed', () {
      expect(economy.itemBrewSeconds(0, 0), near(4.0));
      expect(economy.itemBrewSeconds(1, 0), near(4.6));
      expect(economy.itemBrewSeconds(0, 25), near(4.0 / 12.0));
    });
  });

  group('helper, radio, seats', () {
    test('helper efficiency', () {
      expect(economy.helperEfficiency(0), 0);
      expect(economy.helperEfficiency(1), near(0.25));
      expect(economy.helperEfficiency(4), near(0.295));
      expect(economy.helperEfficiency(50), near(0.985));
    });

    test('radio tip and VIP numbers', () {
      expect(economy.tipRate(0), 0);
      expect(economy.tipRate(3), near(0.03));
      expect(economy.tipRate(50), near(0.5));
      expect(economy.vipTipMultiplier(0), 1.0);
      expect(economy.vipTipMultiplier(3), near(1.06));
      expect(economy.vipMaxGapSeconds(0), 300);
      expect(economy.vipMaxGapSeconds(50), near(240));
      expect(economy.vipMaxGapSeconds(1000), config.vipMinGapSeconds);
    });

    test('seat count follows the seats level and stops at the maximum', () {
      expect(economy.seatCount(0), 2);
      expect(economy.seatCount(4), 2);
      expect(economy.seatCount(5), 3);
      expect(economy.seatCount(10), 4);
      expect(economy.seatCount(25), 7);
      expect(economy.seatCount(50), 12);
      expect(economy.seatCount(1000), config.seatsMax);
    });
  });

  group('softMin', () {
    test('is below both inputs and close to the smaller one', () {
      final double value = economy.softMin(1.0, 100.0);
      expect(value, lessThan(1.0));
      expect(value, greaterThan(0.99));
      expect(economy.softMin(3.0, 3.0), lessThan(3.0));
      expect(economy.softMin(2.0, 5.0), near(economy.softMin(5.0, 2.0)));
    });

    test('is zero when one side is not producing', () {
      expect(economy.softMin(0, 5), 0);
      expect(economy.softMin(5, -1), 0);
    });
  });

  group('effectValue', () {
    test('shows the number that belongs to each row', () {
      expect(economy.effectValue(index('chulha'), 1), near(1.2));
      expect(economy.effectValue(index('kettle'), 25), near(14.5));
      expect(economy.effectValue(index('seats'), 0), near(1.0));
      expect(economy.effectValue(index('helper'), 0), 0);
      expect(economy.effectValue(index('helper'), 1), near(0.25));
      expect(economy.effectValue(index('board'), 25), near(9.5));
      expect(economy.effectValue(index('radio'), 10), near(0.1));
    });
  });

  group('snapshots (golden)', () {
    test('S0: a brand-new stall', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[0, 0, 0, 0, 0, 0],
        unlocked: <bool>[true, false, false, false],
      );
      expect(s.brewRate, near(0.25));
      expect(s.customerRate, near(0.55));
      expect(s.throughput, near(0.242631));
      expect(s.avgPrice, near(10));
      expect(s.fullRate, near(2.426306));
      expect(s.helperEfficiency, 0);
      expect(s.idleRate, 0);
      expect(s.refRate, near(0.606576));
      expect(s.tapCoins, near(3.227892));
      expect(s.seatCount, 2);
      expect(s.bottleneck, Bottleneck.production);
    });

    test('S0 with the free helper running', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[0, 0, 0, 0, 0, 0],
        unlocked: <bool>[true, false, false, false],
        freeHelper: true,
      );
      expect(s.helperEfficiency, near(0.25));
      expect(s.idleRate, near(0.606576));
    });

    test('S1: early game', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[10, 8, 6, 4, 5, 3],
        unlocked: <bool>[true, true, false, false],
      );
      expect(s.brewRate, near(2.06422));
      expect(s.customerRate, near(1.82875));
      expect(s.throughput, near(1.533683));
      expect(s.avgPrice, near(13.6));
      expect(s.avgBrewSeconds, near(4.36));
      expect(s.tipRate, near(0.03));
      expect(s.fullRate, near(21.483837));
      expect(s.helperEfficiency, near(0.295));
      expect(s.idleRate, near(6.337732));
      expect(s.refRate, near(6.337732));
      expect(s.tapCoins, near(9.947151));
      expect(s.seatCount, 3);
      expect(s.bottleneck, Bottleneck.balanced);
    });

    test('S3: everything at level 25', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[25, 25, 25, 25, 25, 25],
        unlocked: <bool>[true, true, true, false],
      );
      expect(s.fullRate, near(737.202976));
      expect(s.idleRate, near(449.693815));
      expect(s.tapCoins, near(226.707768));
      expect(s.seatCount, 7);
    });

    test('S2: everything maxed', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[50, 50, 50, 50, 50, 50],
        unlocked: <bool>[true, true, true, true],
      );
      expect(s.fullRate, near(14701.640774));
      expect(s.idleRate, near(14481.116163));
      expect(s.tapCoins, near(4419.117232));
      expect(s.seatCount, 12);
      expect(s.bottleneck, Bottleneck.production);
    });

    test('customers can be the bottleneck', () {
      final EconomySnapshot s = economy.snapshotFor(
        levels: <int>[30, 0, 0, 0, 0, 0],
        unlocked: <bool>[true, false, false, false],
      );
      expect(s.bottleneck, Bottleneck.customers);
    });

    test('buying any upgrade never lowers the income', () {
      final List<int> base = <int>[7, 5, 4, 2, 3, 1];
      final List<bool> unlocked = <bool>[true, true, false, false];
      final EconomySnapshot before = economy.snapshotFor(levels: base, unlocked: unlocked);
      for (int i = 0; i < base.length; i++) {
        final List<int> next = List<int>.of(base);
        next[i] += 1;
        final EconomySnapshot after = economy.snapshotFor(levels: next, unlocked: unlocked);
        expect(after.fullRate, greaterThanOrEqualTo(before.fullRate), reason: 'upgrade $i');
        expect(after.idleRate, greaterThanOrEqualTo(before.idleRate), reason: 'upgrade $i');
        expect(after.tapCoins, greaterThanOrEqualTo(before.tapCoins), reason: 'upgrade $i');
      }
    });

    test('unlocking a new item raises the income per cup', () {
      final List<int> levels = <int>[10, 10, 10, 1, 10, 0];
      final EconomySnapshot one = economy.snapshotFor(
        levels: levels,
        unlocked: <bool>[true, false, false, false],
      );
      final EconomySnapshot two = economy.snapshotFor(
        levels: levels,
        unlocked: <bool>[true, true, false, false],
      );
      expect(two.avgPrice, greaterThan(one.avgPrice));
    });
  });
}
