import 'dart:convert';

/// Ids of the six upgrades. The order in `game_config.json` is the UI order.
class UpgradeIds {
  UpgradeIds._();

  static const String chulha = 'chulha';
  static const String kettle = 'kettle';
  static const String seats = 'seats';
  static const String helper = 'helper';
  static const String board = 'board';
  static const String radio = 'radio';

  static const List<String> all = <String>[
    chulha,
    kettle,
    seats,
    helper,
    board,
    radio,
  ];
}

/// One upgrade (static balance data, no player state).
class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.baseCost,
    required this.growth,
    required this.perLevel,
    required this.milestoneMult,
    required this.effBase,
    required this.vipTipPerLevel,
    required this.vipSpeedupPerLevel,
  });

  factory UpgradeDef.fromJson(Map<String, dynamic> json) {
    return UpgradeDef(
      id: _stringAt(json, 'id'),
      baseCost: _numAt(json, 'baseCost'),
      growth: _numAt(json, 'growth'),
      perLevel: _numAt(json, 'perLevel'),
      milestoneMult: _numAt(json, 'milestoneMult', 1.0),
      effBase: _numAt(json, 'effBase', 0.0),
      vipTipPerLevel: _numAt(json, 'vipTipPerLevel', 0.0),
      vipSpeedupPerLevel: _numAt(json, 'vipSpeedupPerLevel', 0.0),
    );
  }

  final String id;

  /// Cost of the first level; level n costs `ceil(baseCost * growth^n)`.
  final double baseCost;
  final double growth;

  /// Linear effect per level (meaning depends on the upgrade, see Economy).
  final double perLevel;

  /// The effect is multiplied by this at every `milestoneEvery` levels.
  final double milestoneMult;

  /// Helper only: efficiency at level 1.
  final double effBase;

  /// Radio only: extra VIP tip per level (fraction).
  final double vipTipPerLevel;

  /// Radio only: seconds shaved off the longest VIP gap per level.
  final double vipSpeedupPerLevel;
}

/// One menu item (a kind of chai).
class MenuItemDef {
  const MenuItemDef({
    required this.id,
    required this.price,
    required this.brewMult,
    required this.weight,
    required this.unlockCost,
  });

  factory MenuItemDef.fromJson(Map<String, dynamic> json) {
    return MenuItemDef(
      id: _stringAt(json, 'id'),
      price: _numAt(json, 'price'),
      brewMult: _numAt(json, 'brewMult'),
      weight: _numAt(json, 'weight'),
      unlockCost: _numAt(json, 'unlockCost'),
    );
  }

  final String id;

  /// Coins per cup.
  final double price;

  /// Brew time relative to the base brew time.
  final double brewMult;

  /// How often customers order it (relative).
  final double weight;
  final double unlockCost;
}

/// All balance numbers of the game, loaded from `assets/config/game_config.json`.
///
/// The same file is read by `tool/simulate_economy.py`, so economy changes can be
/// tested with the simulator before they ship.
class GameConfig {
  const GameConfig({
    required this.maxLevel,
    required this.milestoneEvery,
    required this.softMinPower,
    required this.baseBrewSeconds,
    required this.baseBatchCups,
    required this.baseCustomersPerSecond,
    required this.tapCups,
    required this.tapIncomeSeconds,
    required this.upgrades,
    required this.menu,
    required this.newItemWeightBoost,
    required this.offlineCapHours,
    required this.offlineEfficiency,
    required this.offlineMinAwaySeconds,
    required this.boostMultiplier,
    required this.boostDurationSeconds,
    required this.boostMaxStackSeconds,
    required this.vipMinGapSeconds,
    required this.vipMaxGapSeconds,
    required this.vipStaySeconds,
    required this.vipTipSeconds,
    required this.dailyRewardMinutes,
    required this.dailyMinCoins,
    required this.freeHelperSeconds,
    required this.freeHelperCooldownSeconds,
    required this.tutorialTapsStep1,
    required this.seatsBase,
    required this.seatsLevelsPerSeat,
    required this.seatsMax,
  });

  /// Parses and validates the JSON text of `game_config.json`.
  factory GameConfig.parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('game_config.json: top level must be an object');
    }
    return GameConfig.fromJson(decoded);
  }

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> brew = _objectAt(json, 'brew');
    final Map<String, dynamic> customers = _objectAt(json, 'customers');
    final Map<String, dynamic> tap = _objectAt(json, 'tap');
    final Map<String, dynamic> offline = _objectAt(json, 'offline');
    final Map<String, dynamic> boost = _objectAt(json, 'boost');
    final Map<String, dynamic> vip = _objectAt(json, 'vip');
    final Map<String, dynamic> daily = _objectAt(json, 'daily');
    final Map<String, dynamic> freeHelper = _objectAt(json, 'freeHelper');
    final Map<String, dynamic> tutorial = _objectAt(json, 'tutorial');
    final Map<String, dynamic> seatsVisual = _objectAt(json, 'seatsVisual');

    final List<UpgradeDef> upgrades = <UpgradeDef>[];
    for (final Object? entry in _listAt(json, 'upgrades')) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('game_config.json: upgrades must be objects');
      }
      upgrades.add(UpgradeDef.fromJson(entry));
    }

    final List<MenuItemDef> menu = <MenuItemDef>[];
    for (final Object? entry in _listAt(json, 'menu')) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('game_config.json: menu items must be objects');
      }
      menu.add(MenuItemDef.fromJson(entry));
    }

    final List<double> rewardMinutes = <double>[];
    for (final Object? entry in _listAt(daily, 'rewardMinutes')) {
      if (entry is! num) {
        throw const FormatException('game_config.json: rewardMinutes must be numbers');
      }
      rewardMinutes.add(entry.toDouble());
    }

    final GameConfig config = GameConfig(
      maxLevel: _intAt(json, 'maxLevel'),
      milestoneEvery: _intAt(json, 'milestoneEvery'),
      softMinPower: _numAt(json, 'softMinPower'),
      baseBrewSeconds: _numAt(brew, 'baseSeconds'),
      baseBatchCups: _numAt(brew, 'baseBatchCups'),
      baseCustomersPerSecond: _numAt(customers, 'basePerSecond'),
      tapCups: _numAt(tap, 'cups'),
      tapIncomeSeconds: _numAt(tap, 'incomeSeconds'),
      upgrades: List<UpgradeDef>.unmodifiable(upgrades),
      menu: List<MenuItemDef>.unmodifiable(menu),
      newItemWeightBoost: _numAt(json, 'newItemWeightBoost'),
      offlineCapHours: _numAt(offline, 'capHours'),
      offlineEfficiency: _numAt(offline, 'efficiency'),
      offlineMinAwaySeconds: _numAt(offline, 'minAwaySeconds'),
      boostMultiplier: _numAt(boost, 'multiplier'),
      boostDurationSeconds: _numAt(boost, 'durationSeconds'),
      boostMaxStackSeconds: _numAt(boost, 'maxStackSeconds'),
      vipMinGapSeconds: _numAt(vip, 'minGapSeconds'),
      vipMaxGapSeconds: _numAt(vip, 'maxGapSeconds'),
      vipStaySeconds: _numAt(vip, 'staySeconds'),
      vipTipSeconds: _numAt(vip, 'tipSeconds'),
      dailyRewardMinutes: List<double>.unmodifiable(rewardMinutes),
      dailyMinCoins: _numAt(daily, 'minCoins'),
      freeHelperSeconds: _numAt(freeHelper, 'seconds'),
      freeHelperCooldownSeconds: _numAt(freeHelper, 'cooldownSeconds'),
      tutorialTapsStep1: _intAt(tutorial, 'tapsStep1'),
      seatsBase: _intAt(seatsVisual, 'base'),
      seatsLevelsPerSeat: _intAt(seatsVisual, 'levelsPerSeat'),
      seatsMax: _intAt(seatsVisual, 'max'),
    );
    config.validate();
    return config;
  }

  /// Highest level of every upgrade.
  final int maxLevel;

  /// Every this many levels the upgrade effect is multiplied by `milestoneMult`.
  final int milestoneEvery;

  /// Sharpness of the production/customer bottleneck blend (higher = closer to min).
  final double softMinPower;

  final double baseBrewSeconds;
  final double baseBatchCups;
  final double baseCustomersPerSecond;

  /// A tap serves this many cups of the average order.
  final double tapCups;

  /// A tap also pays this many seconds of full-rate income.
  final double tapIncomeSeconds;

  final List<UpgradeDef> upgrades;
  final List<MenuItemDef> menu;

  /// The most recently unlocked item is ordered this many times more often.
  final double newItemWeightBoost;

  final double offlineCapHours;
  final double offlineEfficiency;
  final double offlineMinAwaySeconds;

  final double boostMultiplier;
  final double boostDurationSeconds;
  final double boostMaxStackSeconds;

  final double vipMinGapSeconds;
  final double vipMaxGapSeconds;
  final double vipStaySeconds;
  final double vipTipSeconds;

  /// Minutes of income granted on day 1..7 of the daily reward.
  final List<double> dailyRewardMinutes;
  final double dailyMinCoins;

  final double freeHelperSeconds;
  final double freeHelperCooldownSeconds;

  final int tutorialTapsStep1;

  final int seatsBase;
  final int seatsLevelsPerSeat;
  final int seatsMax;

  double get offlineCapSeconds => offlineCapHours * 3600.0;

  /// Index of the upgrade with [id] in [upgrades].
  int upgradeIndex(String id) {
    for (int i = 0; i < upgrades.length; i++) {
      if (upgrades[i].id == id) {
        return i;
      }
    }
    throw StateError('Unknown upgrade id "$id"');
  }

  /// Throws [FormatException] when the numbers cannot work together.
  void validate() {
    if (maxLevel < 1 || milestoneEvery < 1) {
      throw const FormatException('game_config.json: maxLevel/milestoneEvery must be >= 1');
    }
    if (softMinPower <= 0 ||
        baseBrewSeconds <= 0 ||
        baseBatchCups <= 0 ||
        baseCustomersPerSecond <= 0) {
      throw const FormatException('game_config.json: base rates must be positive');
    }
    if (upgrades.length != UpgradeIds.all.length) {
      throw FormatException(
        'game_config.json: expected ${UpgradeIds.all.length} upgrades, found ${upgrades.length}',
      );
    }
    for (final String id in UpgradeIds.all) {
      bool found = false;
      for (final UpgradeDef def in upgrades) {
        if (def.id == id) {
          found = true;
        }
      }
      if (!found) {
        throw FormatException('game_config.json: missing upgrade "$id"');
      }
    }
    for (final UpgradeDef def in upgrades) {
      if (def.baseCost <= 0 || def.growth < 1.0 || def.milestoneMult < 1.0) {
        throw FormatException('game_config.json: bad numbers for upgrade "${def.id}"');
      }
    }
    if (menu.isEmpty || menu.first.unlockCost != 0) {
      throw const FormatException('game_config.json: the first menu item must be free');
    }
    for (final MenuItemDef item in menu) {
      if (item.price <= 0 || item.brewMult <= 0 || item.weight <= 0 || item.unlockCost < 0) {
        throw FormatException('game_config.json: bad numbers for menu item "${item.id}"');
      }
    }
    if (dailyRewardMinutes.length != 7) {
      throw const FormatException('game_config.json: daily.rewardMinutes needs 7 entries');
    }
    if (offlineEfficiency < 0 || offlineCapHours < 0 || offlineMinAwaySeconds < 0) {
      throw const FormatException('game_config.json: bad offline numbers');
    }
    if (boostMultiplier < 1 ||
        boostDurationSeconds <= 0 ||
        boostMaxStackSeconds < boostDurationSeconds) {
      throw const FormatException('game_config.json: bad boost numbers');
    }
    if (vipMinGapSeconds <= 0 || vipMaxGapSeconds < vipMinGapSeconds || vipStaySeconds <= 0) {
      throw const FormatException('game_config.json: bad VIP numbers');
    }
    if (seatsBase < 1 || seatsLevelsPerSeat < 1 || seatsMax < seatsBase) {
      throw const FormatException('game_config.json: bad seatsVisual numbers');
    }
  }
}

Map<String, dynamic> _objectAt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('game_config.json: "$key" must be an object');
}

List<Object?> _listAt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('game_config.json: "$key" must be a list');
}

double _numAt(Map<String, dynamic> json, String key, [double? fallback]) {
  final Object? value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value == null && fallback != null) {
    return fallback;
  }
  throw FormatException('game_config.json: "$key" must be a number');
}

int _intAt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('game_config.json: "$key" must be a number');
}

String _stringAt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('game_config.json: "$key" must be a non-empty string');
}
