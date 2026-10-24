import 'dart:math' as math;

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/game_state.dart';

/// Which side of the stall limits the income right now.
enum Bottleneck { production, customers, balanced }

/// All derived income numbers for one combination of upgrade levels and menu.
class EconomySnapshot {
  const EconomySnapshot({
    required this.brewRate,
    required this.customerRate,
    required this.throughput,
    required this.avgPrice,
    required this.avgBrewSeconds,
    required this.tipRate,
    required this.fullRate,
    required this.helperEfficiency,
    required this.idleRate,
    required this.refRate,
    required this.tapCoins,
    required this.seatCount,
  });

  /// Cups the kettle and chulha can make per second.
  final double brewRate;

  /// Cups per second customers want to buy.
  final double customerRate;

  /// Cups per second actually sold: a soft minimum of the two rates above.
  final double throughput;

  final double avgPrice;
  final double avgBrewSeconds;

  /// Extra tip, as a fraction (0.1 = +10%).
  final double tipRate;

  /// Coins per second when the stall runs at 100% (player is tapping).
  final double fullRate;

  /// Fraction of [fullRate] earned while the player is not tapping (0 = no helper).
  final double helperEfficiency;

  /// Coins per second without tapping: the number shown as "per second".
  final double idleRate;

  /// Coins per second a helper-run stall would earn: base for daily reward and VIP tips.
  final double refRate;

  /// Coins for one tap on the kettle.
  final double tapCoins;

  /// Seats shown in the scene.
  final int seatCount;

  Bottleneck get bottleneck {
    final double ratio = brewRate / customerRate;
    if (ratio < 0.8) {
      return Bottleneck.production;
    }
    if (ratio > 1.25) {
      return Bottleneck.customers;
    }
    return Bottleneck.balanced;
  }
}

/// Pure formulas of the game economy. No state, no randomness, no time.
///
/// The same formulas live in `tool/simulate_economy.py`; keep both in sync.
///
///   mult(L)      = (1 + perLevel * L) * milestoneMult ^ floor(L / milestoneEvery)
///   brewRate     = baseBatchCups * mult(kettle) * mult(chulha) / avgBrewSeconds
///   customerRate = basePerSecond * mult(seats) * mult(board)
///   throughput   = (brewRate^-p + customerRate^-p)^(-1/p)
///   fullRate     = throughput * avgPrice * (1 + tipRate)
///   idleRate     = fullRate * helperEfficiency
///   tapCoins     = tapCups * avgPrice * (1 + tipRate) + fullRate * tapIncomeSeconds
class Economy {
  Economy(this.config)
    : chulhaIndex = config.upgradeIndex(UpgradeIds.chulha),
      kettleIndex = config.upgradeIndex(UpgradeIds.kettle),
      seatsIndex = config.upgradeIndex(UpgradeIds.seats),
      helperIndex = config.upgradeIndex(UpgradeIds.helper),
      boardIndex = config.upgradeIndex(UpgradeIds.board),
      radioIndex = config.upgradeIndex(UpgradeIds.radio);

  final GameConfig config;
  final int chulhaIndex;
  final int kettleIndex;
  final int seatsIndex;
  final int helperIndex;
  final int boardIndex;
  final int radioIndex;

  /// Effect multiplier of an upgrade at [level] (chulha, kettle, seats, board).
  double levelMult(int upgradeIndex, int level) {
    final UpgradeDef def = config.upgrades[upgradeIndex];
    final int milestones = level ~/ config.milestoneEvery;
    return (1.0 + def.perLevel * level) * math.pow(def.milestoneMult, milestones);
  }

  /// Price of the next level when the upgrade is at [level].
  double upgradeCost(int upgradeIndex, int level) {
    final UpgradeDef def = config.upgrades[upgradeIndex];
    return (def.baseCost * math.pow(def.growth, level)).ceilToDouble();
  }

  /// Price of buying [count] levels in a row.
  double bulkCost(int upgradeIndex, int level, int count) {
    double total = 0;
    for (int i = 0; i < count; i++) {
      total += upgradeCost(upgradeIndex, level + i);
    }
    return total;
  }

  /// How many levels [coins] can buy (never above the level cap).
  int maxAffordable(int upgradeIndex, int level, double coins) {
    int count = 0;
    double total = 0;
    while (level + count < config.maxLevel) {
      final double next = upgradeCost(upgradeIndex, level + count);
      if (total + next > coins) {
        break;
      }
      total += next;
      count++;
    }
    return count;
  }

  /// Relative order frequency of every menu item (0 for locked items).
  List<double> menuWeights(List<bool> unlocked) {
    int latest = 0;
    for (int i = 0; i < unlocked.length; i++) {
      if (unlocked[i]) {
        latest = i;
      }
    }
    final List<double> weights = <double>[];
    for (int i = 0; i < config.menu.length; i++) {
      if (!unlocked[i]) {
        weights.add(0.0);
        continue;
      }
      double weight = config.menu[i].weight;
      if (i == latest && latest > 0) {
        weight *= config.newItemWeightBoost;
      }
      weights.add(weight);
    }
    return weights;
  }

  /// Fraction of full income earned without tapping, for a helper at [level].
  double helperEfficiency(int level) {
    if (level <= 0) {
      return 0.0;
    }
    final UpgradeDef def = config.upgrades[helperIndex];
    return def.effBase + def.perLevel * (level - 1);
  }

  /// Extra tip fraction for a radio at [radioLevel].
  double tipRate(int radioLevel) {
    return config.upgrades[radioIndex].perLevel * radioLevel;
  }

  /// Multiplier on VIP tips for a radio at [radioLevel].
  double vipTipMultiplier(int radioLevel) {
    return 1.0 + config.upgrades[radioIndex].vipTipPerLevel * radioLevel;
  }

  /// Longest wait (seconds) before the next VIP, shortened by the radio.
  double vipMaxGapSeconds(int radioLevel) {
    final double gap =
        config.vipMaxGapSeconds - config.upgrades[radioIndex].vipSpeedupPerLevel * radioLevel;
    return gap < config.vipMinGapSeconds ? config.vipMinGapSeconds : gap;
  }

  /// Seats drawn in the scene.
  int seatCount(int seatsLevel) {
    final int count = config.seatsBase + seatsLevel ~/ config.seatsLevelsPerSeat;
    return count > config.seatsMax ? config.seatsMax : count;
  }

  /// Seconds the kettle needs for one cup of menu item [itemIndex].
  double itemBrewSeconds(int itemIndex, int chulhaLevel) {
    final double speed = levelMult(chulhaIndex, chulhaLevel);
    return config.baseBrewSeconds * config.menu[itemIndex].brewMult / speed;
  }

  /// Smooth minimum: close to min(a, b), but both inputs always matter a little.
  double softMin(double a, double b) {
    if (a <= 0 || b <= 0) {
      return 0.0;
    }
    final double p = config.softMinPower;
    final double sum = math.pow(a, -p).toDouble() + math.pow(b, -p).toDouble();
    return math.pow(sum, -1.0 / p).toDouble();
  }

  /// The number shown on an upgrade row for [level]:
  /// chulha = speed multiplier, kettle = cups per batch, seats/board = multiplier,
  /// helper = efficiency (fraction), radio = tip (fraction).
  double effectValue(int upgradeIndex, int level) {
    if (upgradeIndex == kettleIndex) {
      return config.baseBatchCups * levelMult(kettleIndex, level);
    }
    if (upgradeIndex == helperIndex) {
      return helperEfficiency(level);
    }
    if (upgradeIndex == radioIndex) {
      return tipRate(level);
    }
    return levelMult(upgradeIndex, level);
  }

  /// Income numbers for explicit levels (used by tests and the simulator).
  EconomySnapshot snapshotFor({
    required List<int> levels,
    required List<bool> unlocked,
    bool freeHelper = false,
  }) {
    final List<double> weights = menuWeights(unlocked);
    double weightSum = 0;
    double priceSum = 0;
    double brewSum = 0;
    for (int i = 0; i < weights.length; i++) {
      weightSum += weights[i];
      priceSum += weights[i] * config.menu[i].price;
      brewSum += weights[i] * config.menu[i].brewMult;
    }
    final double avgPrice = priceSum / weightSum;
    final double avgBrewSeconds = config.baseBrewSeconds * brewSum / weightSum;

    final double speed = levelMult(chulhaIndex, levels[chulhaIndex]);
    final double batch = levelMult(kettleIndex, levels[kettleIndex]);
    final double brewRate = config.baseBatchCups * batch * speed / avgBrewSeconds;
    final double customerRate =
        config.baseCustomersPerSecond *
        levelMult(seatsIndex, levels[seatsIndex]) *
        levelMult(boardIndex, levels[boardIndex]);
    final double throughput = softMin(brewRate, customerRate);

    final double tip = tipRate(levels[radioIndex]);
    final double fullRate = throughput * avgPrice * (1.0 + tip);

    int helperLevel = levels[helperIndex];
    if (freeHelper && helperLevel < 1) {
      helperLevel = 1;
    }
    final double efficiency = helperEfficiency(helperLevel);
    final double minEfficiency = config.upgrades[helperIndex].effBase;
    final double refEfficiency = efficiency > minEfficiency ? efficiency : minEfficiency;

    return EconomySnapshot(
      brewRate: brewRate,
      customerRate: customerRate,
      throughput: throughput,
      avgPrice: avgPrice,
      avgBrewSeconds: avgBrewSeconds,
      tipRate: tip,
      fullRate: fullRate,
      helperEfficiency: efficiency,
      idleRate: fullRate * efficiency,
      refRate: fullRate * refEfficiency,
      tapCoins: config.tapCups * avgPrice * (1.0 + tip) + fullRate * config.tapIncomeSeconds,
      seatCount: seatCount(levels[seatsIndex]),
    );
  }

  /// Income numbers for the player's current state (a running free helper counts).
  EconomySnapshot snapshot(GameState state) {
    return snapshotFor(
      levels: state.levels,
      unlocked: state.unlocked,
      freeHelper: state.freeHelperLeft > 0,
    );
  }
}
