import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/daily.dart';
import 'package:chai_tapri/core/economy.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/game_state.dart';

import 'support/test_support.dart';

const int _tapsPerSecond = 3;

/// A simple greedy player used to check the pacing of the whole game.
///
/// Every simulated second it taps three times, collects the income and then buys
/// the option with the best price-per-gain (waiting for it when it is too expensive).
/// `tool/simulate_economy.py` contains the same player for balance work.
class _Bot {
  _Bot(this.engine) : economy = engine.economy;

  final GameEngine engine;
  final Economy economy;

  /// Seconds of play until the next VIP customer.
  double vipTimer = 240.0;

  /// Seconds of play when each milestone happened (-1 = not yet).
  double playSeconds = 0;
  double firstUpgradeAt = -1;
  double helperAt = -1;
  final Map<int, double> menuUnlockedAt = <int, double>{};

  double _value(EconomySnapshot snapshot) {
    return snapshot.idleRate + _tapsPerSecond * snapshot.tapCoins;
  }

  /// One second of play. [vipMultiplier] is 2 when the player watches the VIP ad.
  void playSecond({bool vip = true, double vipMultiplier = 1.0}) {
    for (int i = 0; i < _tapsPerSecond; i++) {
      engine.tap();
    }
    engine.tick(1.0);
    playSeconds += 1.0;
    if (vip) {
      vipTimer -= 1.0;
      if (vipTimer <= 0) {
        vipTimer = 240.0;
        engine.addCoins(engine.vipTip() * vipMultiplier);
      }
    }
    shop();
  }

  /// Buys while the best option is affordable.
  void shop() {
    for (int guard = 0; guard < 50; guard++) {
      final _Option? best = _bestOption();
      if (best == null || best.cost > engine.state.coins) {
        return;
      }
      if (best.menuIndex >= 0) {
        engine.unlockMenu(best.menuIndex);
        menuUnlockedAt[best.menuIndex] = playSeconds;
      } else {
        engine.buyUpgrade(best.upgradeIndex, BuyMode.one);
        if (firstUpgradeAt < 0) {
          firstUpgradeAt = playSeconds;
        }
        if (best.upgradeIndex == economy.helperIndex && helperAt < 0) {
          helperAt = playSeconds;
        }
      }
    }
  }

  _Option? _bestOption() {
    final GameState state = engine.state;
    final double baseValue = _value(engine.snapshot);
    _Option? best;
    double bestScore = double.infinity;
    for (int i = 0; i < state.levels.length; i++) {
      if (state.levels[i] >= engine.config.maxLevel) {
        continue;
      }
      final List<int> levels = List<int>.of(state.levels);
      levels[i] += 1;
      final EconomySnapshot next = economy.snapshotFor(levels: levels, unlocked: state.unlocked);
      final double cost = engine.nextCost(i);
      final double score = _score(cost, _value(next) - baseValue, baseValue);
      if (score < bestScore) {
        bestScore = score;
        best = _Option(upgradeIndex: i, menuIndex: -1, cost: cost);
      }
    }
    final int menu = engine.nextMenuToUnlock;
    if (menu >= 0) {
      final List<bool> unlocked = List<bool>.of(state.unlocked);
      unlocked[menu] = true;
      final EconomySnapshot next = economy.snapshotFor(levels: state.levels, unlocked: unlocked);
      final double cost = engine.config.menu[menu].unlockCost;
      final double score = _score(cost, _value(next) - baseValue, baseValue);
      if (score < bestScore) {
        bestScore = score;
        best = _Option(upgradeIndex: -1, menuIndex: menu, cost: cost);
      }
    }
    return best;
  }

  double _score(double cost, double gain, double baseValue) {
    if (gain <= 1e-12) {
      return 1e18 + cost;
    }
    final double missing = cost - engine.state.coins;
    final double wait = (missing > 0 ? missing : 0.0) / (baseValue > 1e-9 ? baseValue : 1e-9);
    return cost / gain + wait;
  }

  bool get everythingMaxed {
    for (final int level in engine.state.levels) {
      if (level < engine.config.maxLevel) {
        return false;
      }
    }
    return true;
  }
}

class _Option {
  const _Option({required this.upgradeIndex, required this.menuIndex, required this.cost});

  final int upgradeIndex;
  final int menuIndex;
  final double cost;
}

/// Plays day after day: a first continuous session, then short sessions at the given
/// hours. Returns the (fractional) day on which every upgrade was at the level cap,
/// or -1 when that did not happen within [maxDays].
double _daysUntilMaxed({
  required List<int> firstDayHours,
  required List<int> hours,
  required int sessionMinutes,
  required bool ads,
  required int maxDays,
}) {
  final GameConfig config = loadTestConfig();
  final GameEngine engine = newEngine(config: config);
  final _Bot bot = _Bot(engine);
  final int baseMs = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;

  int nowMs(double seconds) => baseMs + (seconds * 1000.0).round();

  // First session: 25 minutes, no ads, no VIP customers yet.
  engine.applyOffline(nowMs(0));
  for (int second = 0; second < 25 * 60; second++) {
    bot.playSecond(vip: false);
  }
  double clock = 25 * 60.0;
  engine.state.lastSeenMs = nowMs(clock);

  for (int day = 0; day < maxDays; day++) {
    final List<int> sessionHours = (day == 0) ? firstDayHours : hours;
    for (int k = 0; k < sessionHours.length; k++) {
      final double start = day * 86400.0 + sessionHours[k] * 3600.0;
      if (start <= clock) {
        continue;
      }
      clock = start;
      final int now = nowMs(clock);
      engine.applyOffline(now);
      if (engine.state.pendingOffline > 0) {
        engine.claimPendingOffline(ads ? 2.0 : 1.0);
      }
      if (k == 0) {
        final String today = dateKey(DateTime.fromMillisecondsSinceEpoch(now, isUtc: true));
        engine.claimDaily(today, ads ? 2.0 : 1.0);
      }
      if (ads) {
        while (engine.canAddBoost) {
          engine.grantBoost();
        }
      }
      bot.vipTimer = 240.0;
      for (int second = 0; second < sessionMinutes * 60; second++) {
        bot.playSecond(vipMultiplier: ads ? 2.0 : 1.0);
        clock += 1.0;
        if (bot.everythingMaxed) {
          return clock / 86400.0;
        }
      }
      engine.state.boostLeft = 0;
      engine.state.lastSeenMs = nowMs(clock);
    }
  }
  return -1;
}

/// Fails the test when the game state is not valid.
void _assertHealthy(GameEngine engine, String where) {
  final GameState state = engine.state;
  final GameConfig config = engine.config;
  if (!state.coins.isFinite || state.coins < 0) {
    fail('$where: coins are ${state.coins}');
  }
  if (!state.lifetimeCoins.isFinite || state.lifetimeCoins < state.coins) {
    fail('$where: lifetime ${state.lifetimeCoins} below coins ${state.coins}');
  }
  for (int i = 0; i < state.levels.length; i++) {
    if (state.levels[i] < 0 || state.levels[i] > config.maxLevel) {
      fail('$where: level $i is ${state.levels[i]}');
    }
  }
  if (!state.unlocked.first) {
    fail('$where: the first menu item must always be unlocked');
  }
  for (int i = 1; i < state.unlocked.length; i++) {
    if (state.unlocked[i] && !state.unlocked[i - 1]) {
      fail('$where: menu item $i unlocked before item ${i - 1}');
    }
  }
  if (state.boostLeft < 0 || state.boostLeft > config.boostMaxStackSeconds) {
    fail('$where: boost is ${state.boostLeft}');
  }
  if (state.freeHelperLeft < 0 || state.freeHelperLeft > config.freeHelperSeconds) {
    fail('$where: free helper is ${state.freeHelperLeft}');
  }
  if (state.dailyStreak < 0 || state.dailyStreak > 7) {
    fail('$where: streak is ${state.dailyStreak}');
  }
  if (!state.pendingOffline.isFinite || state.pendingOffline < 0) {
    fail('$where: pending offline is ${state.pendingOffline}');
  }
  final EconomySnapshot snapshot = engine.snapshot;
  for (final double value in <double>[snapshot.fullRate, snapshot.idleRate, snapshot.tapCoins]) {
    if (!value.isFinite || value < 0) {
      fail('$where: income value $value');
    }
  }
}

void main() {
  group('first hour of play', () {
    late _Bot bot;

    setUpAll(() {
      bot = _Bot(newEngine());
      for (int second = 0; second < 60 * 60; second++) {
        bot.playSecond(vip: false);
      }
    });

    test('the first upgrade comes within a minute', () {
      expect(bot.firstUpgradeAt, greaterThan(0));
      expect(bot.firstUpgradeAt, lessThanOrEqualTo(60));
    });

    test('masala chai is unlocked in the first minutes', () {
      expect(bot.menuUnlockedAt[1], isNotNull);
      expect(bot.menuUnlockedAt[1]!, lessThanOrEqualTo(10 * 60));
    });

    test('the helper is bought within a quarter of an hour', () {
      expect(bot.helperAt, greaterThan(0));
      expect(bot.helperAt, lessThanOrEqualTo(15 * 60));
    });

    test('ginger chai is unlocked within the first hour, kulhad chai is not', () {
      expect(bot.menuUnlockedAt[2], isNotNull);
      expect(bot.menuUnlockedAt[2]!, lessThanOrEqualTo(40 * 60));
      expect(bot.menuUnlockedAt[3], isNull);
    });

    test('nothing is maxed after an hour and the state stays valid', () {
      expect(bot.everythingMaxed, isFalse);
      _assertHealthy(bot.engine, 'after one hour');
    });
  });

  group('long-term pacing', () {
    test('an engaged player with ads needs more than five days to max everything', () {
      final double days = _daysUntilMaxed(
        firstDayHours: <int>[3, 6, 9, 12, 15, 18, 21],
        hours: <int>[8, 13, 18, 22],
        sessionMinutes: 6,
        ads: true,
        maxDays: 40,
      );
      expect(days, greaterThan(5), reason: 'the game would be over too fast');
      expect(days, lessThan(20), reason: 'an engaged player should finish within three weeks');
    });

    test('a casual player without ads takes weeks but does finish', () {
      final double days = _daysUntilMaxed(
        firstDayHours: <int>[9, 20],
        hours: <int>[9, 20],
        sessionMinutes: 5,
        ads: false,
        maxDays: 90,
      );
      expect(days, greaterThan(18), reason: 'a casual player should not finish in under 18 days');
      expect(days, lessThan(70), reason: 'the end must be reachable without ads');
    });
  });

  group('random play', () {
    test('thirty thousand random actions never break the rules', () {
      final math.Random random = math.Random(2026);
      final GameEngine engine = newEngine();
      int nowMs = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
      for (int step = 0; step < 30000; step++) {
        switch (random.nextInt(13)) {
          case 0:
            engine.tap();
          case 1:
            engine.tick(random.nextDouble() * 5);
          case 2:
            engine.addCoins(random.nextDouble() * math.pow(10, random.nextInt(9)));
          case 3:
            engine.buyUpgrade(random.nextInt(engine.state.levels.length), BuyMode.values[random.nextInt(3)]);
          case 4:
            engine.unlockMenu(random.nextInt(engine.state.unlocked.length));
          case 5:
            // Up to 12 hours forward, sometimes an hour backwards.
            nowMs += random.nextInt(13 * 3600 * 1000) - 3600 * 1000;
            engine.applyOffline(nowMs);
          case 6:
            engine.claimPendingOffline(random.nextBool() ? 2.0 : 1.0);
          case 7:
            final DateTime day = DateTime.utc(2026, 10, 1 + random.nextInt(40));
            engine.claimDaily(dateKey(day), random.nextBool() ? 2.0 : 1.0);
          case 8:
            engine.grantBoost();
          case 9:
            if (engine.freeHelperAvailable(nowMs)) {
              engine.grantFreeHelper(nowMs);
            }
          case 10:
            engine.addCoins(engine.vipTip());
          case 11:
            engine.tick(0.1);
          default:
            engine.state.freeHelperLeft = 0;
            engine.invalidate();
        }
        _assertHealthy(engine, 'step $step');
      }
      // Whatever happened, the result can be saved and loaded again.
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(engine.state.toJson())) as Map<String, dynamic>;
      final GameState copy = GameState.fromJson(json, engine.config);
      expect(copy.toJson(), engine.state.toJson());
    });
  });
}
