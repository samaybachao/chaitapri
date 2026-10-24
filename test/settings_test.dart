import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/key_value_store.dart';
import 'package:chai_tapri/state/settings_controller.dart';

import 'support/fakes.dart';

SettingsController make({
  String? system,
  MemoryKeyValueStore? store,
  Haptics? haptics,
}) {
  return SettingsController(
    store: store ?? MemoryKeyValueStore(),
    haptics: haptics ?? Haptics(enabled: false),
    systemLanguageCode: system,
  );
}

void main() {
  silenceDebugPrint();

  group('language', () {
    test('follows a supported phone language until the player chooses', () {
      expect(make(system: 'hi').languageCode, 'hi');
      expect(make(system: 'en').languageCode, 'en');
      expect(make(system: 'fr').languageCode, 'en');
      expect(make().languageCode, 'en');
      expect(make(system: 'hi').languageChosen, isFalse);
    });

    test('setLanguage changes the texts, notifies and is remembered', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SettingsController settings = make(system: 'en', store: store);
      int notified = 0;
      settings.addListener(() => notified += 1);

      await settings.setLanguage('hi');
      expect(settings.languageCode, 'hi');
      expect(settings.languageChosen, isTrue);
      expect(settings.strings.t('tab_menu'), isNot(settings.strings.t('tab_upgrades')));
      expect(notified, 1);

      final SettingsController reopened = make(system: 'en', store: store);
      await reopened.load();
      expect(reopened.languageCode, 'hi');
      expect(reopened.languageChosen, isTrue);
    });

    test('an unknown language code is ignored', () async {
      final SettingsController settings = make(system: 'en');
      await settings.setLanguage('xx');
      expect(settings.languageCode, 'en');
      expect(settings.languageChosen, isFalse);
    });
  });

  group('vibration', () {
    test('the switch drives the haptics and is remembered', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final Haptics haptics = Haptics();
      final SettingsController settings = make(store: store, haptics: haptics);
      expect(settings.vibration, isTrue);

      await settings.setVibration(false);
      expect(settings.vibration, isFalse);
      expect(haptics.enabled, isFalse);

      final Haptics otherHaptics = Haptics();
      final SettingsController reopened = make(store: store, haptics: otherHaptics);
      await reopened.load();
      expect(reopened.vibration, isFalse);
      expect(otherHaptics.enabled, isFalse);
    });
  });

  group('damaged data', () {
    test('garbage in storage falls back to the defaults', () async {
      for (final String raw in <String>['', 'not json', '[]', '{"lang": 5, "vibration": "x"}']) {
        final MemoryKeyValueStore store = MemoryKeyValueStore(<String, String>{
          SettingsController.storageKey: raw,
        });
        final SettingsController settings = make(system: 'hi', store: store);
        await settings.load();
        expect(settings.languageCode, 'hi', reason: raw);
        expect(settings.vibration, isTrue, reason: raw);
        expect(settings.languageChosen, isFalse, reason: raw);
      }
    });

    test('an unsupported saved language is ignored', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore(<String, String>{
        SettingsController.storageKey: '{"v":1,"lang":"zz","vibration":true}',
      });
      final SettingsController settings = make(system: 'hi', store: store);
      await settings.load();
      expect(settings.languageCode, 'hi');
      expect(settings.languageChosen, isFalse);
    });
  });
}
