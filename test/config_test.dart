import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';

import 'support/test_support.dart';

Map<String, dynamic> _rawConfig() {
  final String source = File('assets/config/game_config.json').readAsStringSync();
  return jsonDecode(source) as Map<String, dynamic>;
}

void main() {
  group('GameConfig', () {
    test('the shipped game_config.json is valid', () {
      final GameConfig config = loadTestConfig();
      expect(config.upgrades.map((UpgradeDef u) => u.id).toList(), UpgradeIds.all);
      expect(config.menu.length, 4);
      expect(config.menu.first.unlockCost, 0);
      expect(config.maxLevel, 50);
      expect(config.milestoneEvery, 25);
      expect(config.dailyRewardMinutes, <double>[10, 15, 20, 30, 45, 60, 120]);
      expect(config.offlineCapHours, 3.0);
      expect(config.offlineEfficiency, 0.5);
      expect(config.boostDurationSeconds, 300);
      expect(config.boostMaxStackSeconds, 1200);
    });

    test('upgradeIndex finds every upgrade and rejects unknown ids', () {
      final GameConfig config = loadTestConfig();
      for (int i = 0; i < UpgradeIds.all.length; i++) {
        expect(config.upgradeIndex(UpgradeIds.all[i]), i);
      }
      expect(() => config.upgradeIndex('nope'), throwsStateError);
    });

    test('rejects a config with a missing upgrade', () {
      final Map<String, dynamic> json = _rawConfig();
      (json['upgrades'] as List<dynamic>).removeLast();
      expect(() => GameConfig.fromJson(json), throwsFormatException);
    });

    test('rejects a config whose first menu item is not free', () {
      final Map<String, dynamic> json = _rawConfig();
      final List<dynamic> menu = json['menu'] as List<dynamic>;
      (menu.first as Map<String, dynamic>)['unlockCost'] = 5;
      expect(() => GameConfig.fromJson(json), throwsFormatException);
    });

    test('rejects missing sections and wrong types', () {
      final Map<String, dynamic> json = _rawConfig();
      json.remove('offline');
      expect(() => GameConfig.fromJson(json), throwsFormatException);

      final Map<String, dynamic> wrong = _rawConfig();
      wrong['maxLevel'] = 'fifty';
      expect(() => GameConfig.fromJson(wrong), throwsFormatException);

      expect(() => GameConfig.parse('[]'), throwsFormatException);
      expect(() => GameConfig.parse('not json'), throwsFormatException);
    });
  });
}
