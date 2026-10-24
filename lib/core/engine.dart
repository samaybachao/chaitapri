import 'dart:math' as math;

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/daily.dart';
import 'package:chai_tapri/core/economy.dart';
import 'package:chai_tapri/core/game_state.dart';

/// How many upgrade levels one press of the Buy button purchases.
enum BuyMode { one, ten, max }

/// Result of buying upgrade levels.
class PurchaseResult {
  const PurchaseResult({required this.count, required this.cost});

  static const PurchaseResult none = PurchaseResult(count: 0, cost: 0);

  /// Levels bought (0 = nothing happened).
  final int count;

  /// Coins spent.
  final double cost;

  bool get success => count > 0;
}

/// What the player earned while away.
class OfflineOutcome {
  const OfflineOutcome({
    required this.coins,
    required this.awaySeconds,
    required this.creditedSeconds,
    required this.capped,
    required this.showPopup,
  });

  static const OfflineOutcome none = OfflineOutcome(
    coins: 0,
    awaySeconds: 0,
    creditedSeconds: 0,
    capped: false,
    showPopup: false,
  );

  /// Coins earned.
  final double coins;

  /// Real time the player was away.
  final double awaySeconds;

  /// Part of [awaySeconds] that counted (limited by the offline cap).
  final double creditedSeconds;

  /// True when the offline cap was reached (the stall was "full").
  final bool capped;

  /// True when the coins wait in `pendingOffline` for the Welcome-back popup;
  /// false when they were credited silently (short absence).
  final bool showPopup;
}

/// State of the 7-day daily reward for one calendar day.
class DailyInfo {
  const DailyInfo({
    required this.canClaim,
    required this.day,
    required this.claimedThrough,
    required this.reward,
  });

  /// A reward is ready to claim today.
  final bool canClaim;

  /// Day of the 7-day cycle (1..7) that today represents.
  final int day;

  /// Days of the current cycle already claimed (today's day counts once claimed).
  final int claimedThrough;

  /// Coins for [day] at today's income.
  final double reward;
}

/// The game rules: every change to a [GameState] goes through here.
///
/// Pure Dart (no Flutter, no clock, no randomness unless passed in), so every rule
/// is covered by plain unit tests.
class GameEngine {
  GameEngine({required this.config, required this.state}) : economy = Economy(config);

  final GameConfig config;
  final GameState state;
  final Economy economy;

  EconomySnapshot? _snapshot;

  /// Income numbers for the current state. Cached until [invalidate] is called.
  EconomySnapshot get snapshot {
    final EconomySnapshot? cached = _snapshot;
    if (cached != null) {
      return cached;
    }
    final EconomySnapshot fresh = economy.snapshot(state);
    _snapshot = fresh;
    return fresh;
  }

  /// Call after anything that changes levels, the menu or the free helper.
  void invalidate() {
    _snapshot = null;
  }

  /// 2x while a boost is running, otherwise 1x.
  double get boostMultiplier => state.boostLeft > 0 ? config.boostMultiplier : 1.0;

  /// True when something (a bought or free helper) runs the stall without taps.
  bool get helperActive => snapshot.helperEfficiency > 0;

  void addCoins(double amount) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      return;
    }
    state.coins += amount;
    state.lifetimeCoins += amount;
  }

  // ---------------------------------------------------------------- game loop

  /// Advances the game by [seconds]. Returns the coins earned without tapping.
  double tick(double seconds) {
    if (seconds.isNaN || seconds <= 0) {
      return 0;
    }
    final double gained = snapshot.idleRate * boostMultiplier * seconds;
    addCoins(gained);
    if (state.boostLeft > 0) {
      state.boostLeft = state.boostLeft - seconds;
      if (state.boostLeft < 0) {
        state.boostLeft = 0;
      }
    }
    if (state.freeHelperLeft > 0) {
      state.freeHelperLeft = state.freeHelperLeft - seconds;
      if (state.freeHelperLeft <= 0) {
        state.freeHelperLeft = 0;
        invalidate();
      }
    }
    return gained;
  }

  /// One tap on the kettle. Returns the coins earned.
  double tap() {
    state.totalTaps += 1;
    final double coins = snapshot.tapCoins * boostMultiplier;
    addCoins(coins);
    return coins;
  }

  // ----------------------------------------------------------------- upgrades

  /// Price of the next level of upgrade [index] (0 when at the level cap).
  double nextCost(int index) {
    final int level = state.levels[index];
    if (level >= config.maxLevel) {
      return 0;
    }
    return economy.upgradeCost(index, level);
  }

  /// Levels that a purchase in [mode] would buy right now, ignoring coins
  /// (for [BuyMode.max]: as many as the coins allow, at least 1 to show a price).
  int plannedCount(int index, BuyMode mode) {
    final int level = state.levels[index];
    final int room = config.maxLevel - level;
    if (room <= 0) {
      return 0;
    }
    switch (mode) {
      case BuyMode.one:
        return 1;
      case BuyMode.ten:
        return room < 10 ? room : 10;
      case BuyMode.max:
        final int affordable = economy.maxAffordable(index, level, state.coins);
        return affordable < 1 ? 1 : affordable;
    }
  }

  /// Price of what a purchase in [mode] would buy.
  double plannedCost(int index, BuyMode mode) {
    final int count = plannedCount(index, mode);
    if (count <= 0) {
      return 0;
    }
    return economy.bulkCost(index, state.levels[index], count);
  }

  bool canBuy(int index, BuyMode mode) {
    final int count = plannedCount(index, mode);
    if (count <= 0) {
      return false;
    }
    return plannedCost(index, mode) <= state.coins;
  }

  /// Buys levels of upgrade [index]. Does nothing when the coins are not enough.
  PurchaseResult buyUpgrade(int index, BuyMode mode) {
    if (!canBuy(index, mode)) {
      return PurchaseResult.none;
    }
    final int count = plannedCount(index, mode);
    final double cost = plannedCost(index, mode);
    state.coins -= cost;
    if (state.coins < 0) {
      state.coins = 0;
    }
    state.levels[index] += count;
    invalidate();
    return PurchaseResult(count: count, cost: cost);
  }

  // --------------------------------------------------------------------- menu

  /// Index of the next menu item that can be unlocked; -1 when all are unlocked.
  int get nextMenuToUnlock {
    for (int i = 0; i < state.unlocked.length; i++) {
      if (!state.unlocked[i]) {
        return i;
      }
    }
    return -1;
  }

  bool canUnlockMenu(int index) {
    if (index != nextMenuToUnlock) {
      return false;
    }
    return state.coins >= config.menu[index].unlockCost;
  }

  /// Unlocks menu item [index] (items unlock in order).
  bool unlockMenu(int index) {
    if (!canUnlockMenu(index)) {
      return false;
    }
    state.coins -= config.menu[index].unlockCost;
    if (state.coins < 0) {
      state.coins = 0;
    }
    state.unlocked[index] = true;
    invalidate();
    return true;
  }

  // ------------------------------------------------------------- offline gain

  /// Call once when the game starts or comes back to the foreground.
  ///
  /// Credits what the stall earned while the player was away: short absences are
  /// added silently, long ones wait in `pendingOffline` for the Welcome-back popup.
  /// Always sets `lastSeenMs` to [nowMs].
  OfflineOutcome applyOffline(int nowMs) {
    final int lastSeen = state.lastSeenMs;
    state.lastSeenMs = nowMs;
    if (lastSeen <= 0 || nowMs <= lastSeen) {
      // First launch, or the device clock moved backwards: no offline earnings.
      return OfflineOutcome.none;
    }
    final double away = (nowMs - lastSeen) / 1000.0;
    final double credited = math.min(away, config.offlineCapSeconds);
    final bool capped = away > config.offlineCapSeconds;
    // Only a bought helper works while the app is closed (not the free ad helper).
    final EconomySnapshot permanent = economy.snapshotFor(
      levels: state.levels,
      unlocked: state.unlocked,
    );
    final double coins = credited * permanent.idleRate * config.offlineEfficiency;
    if (coins <= 0) {
      return OfflineOutcome(
        coins: 0,
        awaySeconds: away,
        creditedSeconds: credited,
        capped: capped,
        showPopup: false,
      );
    }
    final bool popup = away >= config.offlineMinAwaySeconds;
    if (popup) {
      state.pendingOffline += coins;
      state.pendingOfflineSeconds += credited;
      state.pendingOfflineCapped = state.pendingOfflineCapped || capped;
    } else {
      addCoins(coins);
    }
    return OfflineOutcome(
      coins: coins,
      awaySeconds: away,
      creditedSeconds: credited,
      capped: capped,
      showPopup: popup,
    );
  }

  /// Pays out the waiting offline earnings ([multiplier] 2 after a rewarded ad).
  /// Returns the coins added.
  double claimPendingOffline(double multiplier) {
    final double amount = state.pendingOffline * multiplier;
    addCoins(amount);
    state.pendingOffline = 0;
    state.pendingOfflineSeconds = 0;
    state.pendingOfflineCapped = false;
    return amount;
  }

  // -------------------------------------------------------------- daily reward

  /// Coins for day [day] (1..7) of the daily reward at the current income.
  double dailyReward(int day) {
    final int index = day < 1 ? 0 : (day > 7 ? 6 : day - 1);
    final double minutes = config.dailyRewardMinutes[index];
    final double byIncome = minutes * 60.0 * snapshot.refRate;
    return byIncome > config.dailyMinCoins ? byIncome : config.dailyMinCoins;
  }

  /// Daily reward status for the calendar day [today] (`yyyy-MM-dd`, local).
  DailyInfo dailyInfo(String today) {
    final String last = state.lastDailyDate;
    final int streak = state.dailyStreak;
    bool canClaim = true;
    int day = 1;
    int claimedThrough = 0;
    if (last.isNotEmpty) {
      final int? gap = daysBetween(last, today);
      if (gap != null) {
        if (gap <= 0) {
          // Already claimed today (or the device clock moved backwards).
          canClaim = false;
          day = streak < 1 ? 1 : streak;
          claimedThrough = day;
        } else if (gap == 1) {
          if (streak >= 7) {
            day = 1;
            claimedThrough = 0;
          } else {
            day = streak + 1;
            claimedThrough = streak;
          }
        }
        // gap >= 2: a day was missed, the cycle restarts at day 1 (defaults above).
      }
    }
    return DailyInfo(
      canClaim: canClaim,
      day: day,
      claimedThrough: claimedThrough,
      reward: dailyReward(day),
    );
  }

  /// Claims today's reward ([multiplier] 2 after a rewarded ad). Returns the coins
  /// added, or 0 when there was nothing to claim.
  double claimDaily(String today, double multiplier) {
    final DailyInfo info = dailyInfo(today);
    if (!info.canClaim) {
      return 0;
    }
    final double amount = info.reward * multiplier;
    addCoins(amount);
    state.lastDailyDate = today;
    state.dailyStreak = info.day;
    return amount;
  }

  // ---------------------------------------------------------------------- VIP

  /// Tip paid by a VIP customer.
  double vipTip() {
    final int radioLevel = state.levels[economy.radioIndex];
    return config.vipTipSeconds * snapshot.refRate * economy.vipTipMultiplier(radioLevel);
  }

  /// Seconds until the next VIP customer shows up.
  double nextVipDelay(math.Random random) {
    final int radioLevel = state.levels[economy.radioIndex];
    final double longest = economy.vipMaxGapSeconds(radioLevel);
    final double shortest = config.vipMinGapSeconds;
    return shortest + random.nextDouble() * (longest - shortest);
  }

  // -------------------------------------------------------- boost & free helper

  /// True when another rewarded boost still fits under the stacking limit.
  bool get canAddBoost {
    return state.boostLeft + config.boostDurationSeconds <= config.boostMaxStackSeconds + 0.001;
  }

  void grantBoost() {
    final double total = state.boostLeft + config.boostDurationSeconds;
    state.boostLeft = total > config.boostMaxStackSeconds ? config.boostMaxStackSeconds : total;
  }

  /// True when the player may request the free helper (no bought helper yet).
  bool freeHelperAvailable(int nowMs) {
    return state.levels[economy.helperIndex] == 0 &&
        state.freeHelperLeft <= 0 &&
        nowMs >= state.freeHelperReadyAtMs;
  }

  void grantFreeHelper(int nowMs) {
    state.freeHelperLeft = config.freeHelperSeconds;
    state.freeHelperReadyAtMs = nowMs + (config.freeHelperCooldownSeconds * 1000.0).round();
    invalidate();
  }
}
