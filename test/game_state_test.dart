import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/game_state.dart';

import 'support/test_support.dart';

void main() {
  test('replaceWith copies every field and shares nothing', () {
    final config = loadTestConfig();
    final GameState source = GameState.initial(config, nowMs: 1000)
      ..coins = 12.5
      ..lifetimeCoins = 99
      ..tutorialStep = 2
      ..totalTaps = 7
      ..lastSeenMs = 5000
      ..boostLeft = 120
      ..freeHelperLeft = 30
      ..freeHelperReadyAtMs = 777
      ..dailyStreak = 3
      ..lastDailyDate = '2026-10-23'
      ..pendingOffline = 40
      ..pendingOfflineSeconds = 50
      ..pendingOfflineCapped = true
      ..sessions = 4
      ..vipServed = 2;
    source.levels[0] = 9;
    source.levels[3] = 2;
    source.unlocked[1] = true;

    final GameState target = GameState.initial(config);
    target.replaceWith(source);

    expect(target.toJson(), source.toJson());

    source.levels[0] = 1;
    source.unlocked[1] = false;
    expect(target.levels[0], 9);
    expect(target.unlocked[1], isTrue);
  });

  test('replaceWith a fresh state resets everything', () {
    final config = loadTestConfig();
    final GameState state = GameState.initial(config)
      ..coins = 1e9
      ..sessions = 50
      ..dailyStreak = 6
      ..lastDailyDate = '2026-10-23';
    state.levels[2] = 40;
    state.unlocked[2] = true;

    state.replaceWith(GameState.initial(config, nowMs: 42));

    expect(state.coins, 0);
    expect(state.sessions, 0);
    expect(state.dailyStreak, 0);
    expect(state.lastDailyDate, '');
    expect(state.levels.every((int level) => level == 0), isTrue);
    expect(state.unlocked.where((bool open) => open).length, 1);
    expect(state.createdAtMs, 42);
  });
}
