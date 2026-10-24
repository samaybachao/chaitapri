import 'dart:convert';
import 'dart:io';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/game_state.dart';

/// Loads the real `assets/config/game_config.json` (tests run from the project root).
GameConfig loadTestConfig() {
  final String source = File('assets/config/game_config.json').readAsStringSync();
  return GameConfig.parse(source);
}

/// The real config with [edit] applied to its JSON first (for "what if" tests).
GameConfig loadTestConfigWith(void Function(Map<String, dynamic> json) edit) {
  final String source = File('assets/config/game_config.json').readAsStringSync();
  final Map<String, dynamic> json = jsonDecode(source) as Map<String, dynamic>;
  edit(json);
  return GameConfig.fromJson(json);
}

/// A new game on the real config.
GameEngine newEngine({GameConfig? config, int nowMs = 0}) {
  final GameConfig effective = config ?? loadTestConfig();
  return GameEngine(config: effective, state: GameState.initial(effective, nowMs: nowMs));
}

/// Sets the upgrade levels of [engine] (in the order of the config) and clears the cache.
void setLevels(GameEngine engine, List<int> levels) {
  for (int i = 0; i < levels.length; i++) {
    engine.state.levels[i] = levels[i];
  }
  engine.invalidate();
}

/// Unlocks the first [count] menu items.
void unlockFirst(GameEngine engine, int count) {
  for (int i = 0; i < engine.state.unlocked.length; i++) {
    engine.state.unlocked[i] = i < count;
  }
  engine.invalidate();
}
