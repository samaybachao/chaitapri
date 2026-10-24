import 'package:chai_tapri/core/config.dart';

/// Everything that is saved about the player's progress.
///
/// Plain mutable data: [GameEngine] changes it, `SaveService` stores it.
class GameState {
  GameState({required this.levels, required this.unlocked});

  /// A brand-new game for [config].
  factory GameState.initial(GameConfig config, {int nowMs = 0}) {
    final List<bool> unlocked = List<bool>.filled(config.menu.length, false);
    unlocked[0] = true;
    final GameState state = GameState(
      levels: List<int>.filled(config.upgrades.length, 0),
      unlocked: unlocked,
    );
    state.createdAtMs = nowMs;
    return state;
  }

  /// Rebuilds a state from saved JSON. Every field is validated and clamped, so a
  /// damaged or hand-edited save can never crash the game or create absurd values.
  factory GameState.fromJson(Map<String, dynamic> json, GameConfig config) {
    final GameState state = GameState.initial(config);
    state.coins = _readDouble(json['coins']);
    state.lifetimeCoins = _readDouble(json['lifetime']);
    if (state.lifetimeCoins < state.coins) {
      state.lifetimeCoins = state.coins;
    }

    final Object? savedLevels = json['levels'];
    if (savedLevels is List<Object?>) {
      for (int i = 0; i < state.levels.length && i < savedLevels.length; i++) {
        state.levels[i] = _clampInt(_readInt(savedLevels[i]), 0, config.maxLevel);
      }
    }

    final Object? savedUnlocked = json['unlocked'];
    if (savedUnlocked is List<Object?>) {
      for (int i = 1; i < state.unlocked.length && i < savedUnlocked.length; i++) {
        state.unlocked[i] = savedUnlocked[i] == true;
      }
    }
    // Menu items unlock in order: a gap means the save is damaged, so fill it.
    int highest = 0;
    for (int i = 0; i < state.unlocked.length; i++) {
      if (state.unlocked[i]) {
        highest = i;
      }
    }
    for (int i = 0; i <= highest; i++) {
      state.unlocked[i] = true;
    }

    state.tutorialStep = _clampInt(_readInt(json['tutorial']), 0, 3);
    state.totalTaps = _readInt(json['taps']);
    state.lastSeenMs = _readInt(json['seen']);
    state.createdAtMs = _readInt(json['created']);
    state.boostLeft = _clampDouble(_readDouble(json['boost']), 0, config.boostMaxStackSeconds);
    state.freeHelperLeft = _clampDouble(
      _readDouble(json['freeHelper']),
      0,
      config.freeHelperSeconds,
    );
    state.freeHelperReadyAtMs = _readInt(json['freeHelperReady']);
    state.dailyStreak = _clampInt(_readInt(json['streak']), 0, 7);
    final Object? date = json['dailyDate'];
    state.lastDailyDate = (date is String && _datePattern.hasMatch(date)) ? date : '';
    if (state.lastDailyDate.isEmpty) {
      state.dailyStreak = 0;
    }
    state.pendingOffline = _readDouble(json['pending']);
    state.pendingOfflineSeconds = _readDouble(json['pendingSecs']);
    state.pendingOfflineCapped = json['pendingCapped'] == true;
    state.sessions = _readInt(json['sessions']);
    state.vipServed = _readInt(json['vipServed']);
    return state;
  }

  /// Coins the player can spend now.
  double coins = 0;

  /// All coins ever earned (statistics only).
  double lifetimeCoins = 0;

  /// Level of every upgrade, in the order of `GameConfig.upgrades`.
  final List<int> levels;

  /// Which menu items are unlocked, in the order of `GameConfig.menu`.
  final List<bool> unlocked;

  /// 0 = tap the kettle, 1 = buy an upgrade, 2 = get the helper, 3 = finished.
  int tutorialStep = 0;

  int totalTaps = 0;

  /// Wall-clock time (ms since epoch) of the last save while the app was running.
  int lastSeenMs = 0;
  int createdAtMs = 0;

  /// Seconds of 2x boost left (counts down while the app is open).
  double boostLeft = 0;

  /// Seconds of the free (ad) helper left.
  double freeHelperLeft = 0;

  /// Wall-clock time (ms) from which the free helper can be requested again.
  int freeHelperReadyAtMs = 0;

  /// Day of the 7-day cycle (1..7) claimed last; 0 = nothing claimed yet.
  int dailyStreak = 0;

  /// Local date (yyyy-MM-dd) of the last daily reward; empty = never.
  String lastDailyDate = '';

  /// Offline earnings waiting for the player to press Collect.
  double pendingOffline = 0;
  double pendingOfflineSeconds = 0;
  bool pendingOfflineCapped = false;

  int sessions = 0;
  int vipServed = 0;

  /// Index of the most recently unlocked menu item.
  int get latestUnlocked {
    int latest = 0;
    for (int i = 0; i < unlocked.length; i++) {
      if (unlocked[i]) {
        latest = i;
      }
    }
    return latest;
  }

  /// Copies everything from [other] into this state ("Reset progress" replaces the
  /// running game with a fresh one without creating a new object).
  void replaceWith(GameState other) {
    coins = other.coins;
    lifetimeCoins = other.lifetimeCoins;
    for (int i = 0; i < levels.length && i < other.levels.length; i++) {
      levels[i] = other.levels[i];
    }
    for (int i = 0; i < unlocked.length && i < other.unlocked.length; i++) {
      unlocked[i] = other.unlocked[i];
    }
    tutorialStep = other.tutorialStep;
    totalTaps = other.totalTaps;
    lastSeenMs = other.lastSeenMs;
    createdAtMs = other.createdAtMs;
    boostLeft = other.boostLeft;
    freeHelperLeft = other.freeHelperLeft;
    freeHelperReadyAtMs = other.freeHelperReadyAtMs;
    dailyStreak = other.dailyStreak;
    lastDailyDate = other.lastDailyDate;
    pendingOffline = other.pendingOffline;
    pendingOfflineSeconds = other.pendingOfflineSeconds;
    pendingOfflineCapped = other.pendingOfflineCapped;
    sessions = other.sessions;
    vipServed = other.vipServed;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'coins': _finite(coins),
      'lifetime': _finite(lifetimeCoins),
      'levels': List<int>.of(levels),
      'unlocked': List<bool>.of(unlocked),
      'tutorial': tutorialStep,
      'taps': totalTaps,
      'seen': lastSeenMs,
      'created': createdAtMs,
      'boost': _finite(boostLeft),
      'freeHelper': _finite(freeHelperLeft),
      'freeHelperReady': freeHelperReadyAtMs,
      'streak': dailyStreak,
      'dailyDate': lastDailyDate,
      'pending': _finite(pendingOffline),
      'pendingSecs': _finite(pendingOfflineSeconds),
      'pendingCapped': pendingOfflineCapped,
      'sessions': sessions,
      'vipServed': vipServed,
    };
  }
}

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

double _finite(double value) {
  if (value.isNaN || value.isInfinite || value < 0) {
    return 0;
  }
  return value;
}

double _readDouble(Object? value) {
  if (value is num) {
    return _finite(value.toDouble());
  }
  return 0;
}

int _readInt(Object? value) {
  if (value is int) {
    return value < 0 ? 0 : value;
  }
  if (value is double && value.isFinite) {
    final int converted = value.toInt();
    return converted < 0 ? 0 : converted;
  }
  return 0;
}

int _clampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}

double _clampDouble(double value, double low, double high) {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}
