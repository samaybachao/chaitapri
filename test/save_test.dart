import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/core/save_codec.dart';
import 'package:chai_tapri/services/key_value_store.dart';
import 'package:chai_tapri/services/save_service.dart';

import 'support/test_support.dart';

/// A store whose disk is broken.
class _BrokenStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async {
    throw StateError('disk read failed');
  }

  @override
  Future<void> write(String key, String value) async {
    throw StateError('disk full');
  }

  @override
  Future<void> remove(String key) async {
    throw StateError('disk failed');
  }
}

GameState _busyState(GameConfig config) {
  final GameState state = GameState.initial(config, nowMs: 1700000000000);
  state.coins = 123456.789;
  state.lifetimeCoins = 9876543.21;
  state.levels.setAll(0, <int>[12, 9, 7, 5, 6, 4]);
  state.unlocked[1] = true;
  state.unlocked[2] = true;
  state.tutorialStep = 3;
  state.totalTaps = 4321;
  state.lastSeenMs = 1700000123456;
  state.boostLeft = 222.5;
  state.freeHelperLeft = 100.25;
  state.freeHelperReadyAtMs = 1700000999000;
  state.dailyStreak = 4;
  state.lastDailyDate = '2026-10-21';
  state.pendingOffline = 5555.5;
  state.pendingOfflineSeconds = 7200;
  state.pendingOfflineCapped = true;
  state.sessions = 17;
  state.vipServed = 9;
  return state;
}

void _expectSame(GameState actual, GameState expected) {
  expect(actual.toJson(), expected.toJson());
}

void main() {
  late GameConfig config;

  setUp(() {
    config = loadTestConfig();
  });

  group('checksum and envelope', () {
    test('checksum matches the FNV-1a test vectors', () {
      expect(checksum(''), 0x811C9DC5);
      expect(checksum('a'), 0xE40C292C);
      expect(checksum('foobar'), 0xBF9CF968);
    });

    test('an envelope survives a round trip', () {
      final String raw = encodeEnvelope(sequence: 7, payload: '{"coins":5}');
      final SaveEnvelope? envelope = decodeEnvelope(raw);
      expect(envelope, isNotNull);
      expect(envelope!.version, kSaveVersion);
      expect(envelope.sequence, 7);
      expect(envelope.payload, '{"coins":5}');
    });

    test('a changed payload is detected', () {
      final String raw = encodeEnvelope(sequence: 1, payload: '{"coins":5}');
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      map['p'] = '{"coins":5000000}';
      expect(decodeEnvelope(jsonEncode(map)), isNull);
    });

    test('a truncated save is detected', () {
      final String raw = encodeEnvelope(sequence: 1, payload: '{"coins":5}');
      expect(decodeEnvelope(raw.substring(0, raw.length - 6)), isNull);
    });

    test('garbage is rejected without throwing', () {
      for (final String raw in <String>[
        '',
        'null',
        '[]',
        '42',
        '"text"',
        '{',
        '{"v":1}',
        '{"v":"1","n":1,"c":1,"p":"x"}',
        '{"v":1,"n":1,"c":1,"p":5}',
      ]) {
        expect(decodeEnvelope(raw), isNull, reason: raw);
      }
    });

    test('migrateSave accepts the current version and refuses unknown ones', () {
      final Map<String, dynamic> data = <String, dynamic>{'coins': 1};
      expect(migrateSave(kSaveVersion, data), same(data));
      expect(migrateSave(0, data), isNull);
      expect(migrateSave(kSaveVersion + 1, data), isNull);
    });
  });

  group('GameState json', () {
    test('every field survives a round trip', () {
      final GameState original = _busyState(config);
      final GameState copy = GameState.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        config,
      );
      _expectSame(copy, original);
      expect(copy.coins, original.coins);
      expect(copy.latestUnlocked, 2);
    });

    test('an empty save becomes a fresh game', () {
      final GameState state = GameState.fromJson(<String, dynamic>{}, config);
      _expectSame(state, GameState.initial(config));
      expect(state.unlocked, <bool>[true, false, false, false]);
    });

    test('hand-edited values are clamped', () {
      final GameState state = GameState.fromJson(<String, dynamic>{
        'coins': -50,
        'levels': <Object?>[999, -4, 'x', null, 3.7, 2],
        'tutorial': 99,
        'boost': 999999,
        'freeHelper': 999999,
        'streak': 40,
        'dailyDate': '2026-10-21',
        'taps': -3,
      }, config);
      expect(state.coins, 0);
      expect(state.levels, <int>[config.maxLevel, 0, 0, 0, 3, 2]);
      expect(state.tutorialStep, 3);
      expect(state.boostLeft, config.boostMaxStackSeconds);
      expect(state.freeHelperLeft, config.freeHelperSeconds);
      expect(state.dailyStreak, 7);
      expect(state.totalTaps, 0);
    });

    test('wrong types and infinite numbers do not crash', () {
      final Map<String, dynamic> json = jsonDecode(
        '{"coins": 1e999, "lifetime": "lots", "levels": "none", "unlocked": 5, '
        '"seen": 1e999, "created": [], "pending": null, "dailyDate": 20261021}',
      ) as Map<String, dynamic>;
      final GameState state = GameState.fromJson(json, config);
      expect(state.coins, 0);
      expect(state.lifetimeCoins, 0);
      expect(state.levels, everyElement(0));
      expect(state.lastSeenMs, 0);
      expect(state.lastDailyDate, '');
      expect(state.dailyStreak, 0);
    });

    test('a malformed daily date drops the streak', () {
      final GameState state = GameState.fromJson(<String, dynamic>{
        'streak': 5,
        'dailyDate': 'yesterday',
      }, config);
      expect(state.lastDailyDate, '');
      expect(state.dailyStreak, 0);
    });

    test('a gap in the unlocked menu is filled', () {
      final GameState state = GameState.fromJson(<String, dynamic>{
        'unlocked': <Object?>[true, false, false, true],
      }, config);
      expect(state.unlocked, <bool>[true, true, true, true]);
    });

    test('lifetime coins are never below the current coins', () {
      final GameState state = GameState.fromJson(<String, dynamic>{
        'coins': 500,
        'lifetime': 100,
      }, config);
      expect(state.lifetimeCoins, 500);
    });

    test('toJson never writes NaN or negative numbers', () {
      final GameState state = GameState.initial(config);
      state.coins = double.nan;
      state.lifetimeCoins = double.infinity;
      state.boostLeft = -3;
      final Map<String, Object?> json = state.toJson();
      expect(json['coins'], 0);
      expect(json['lifetime'], 0);
      expect(json['boost'], 0);
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('random states round-trip', () {
      final math.Random random = math.Random(2026);
      for (int round = 0; round < 200; round++) {
        final GameState state = GameState.initial(config, nowMs: random.nextInt(1 << 30));
        state.coins = random.nextDouble() * math.pow(10, random.nextInt(30));
        state.lifetimeCoins = state.coins + random.nextDouble() * 1000;
        for (int i = 0; i < state.levels.length; i++) {
          state.levels[i] = random.nextInt(config.maxLevel + 1);
        }
        final int unlockedCount = 1 + random.nextInt(config.menu.length);
        for (int i = 0; i < state.unlocked.length; i++) {
          state.unlocked[i] = i < unlockedCount;
        }
        state.boostLeft = random.nextDouble() * config.boostMaxStackSeconds;
        state.freeHelperLeft = random.nextDouble() * config.freeHelperSeconds;
        state.totalTaps = random.nextInt(1 << 20);
        state.lastSeenMs = random.nextInt(1 << 30);
        state.pendingOffline = random.nextDouble() * 1e6;
        final GameState copy = GameState.fromJson(
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
          config,
        );
        _expectSame(copy, state);
      }
    });
  });

  group('SaveService', () {
    test('a new player has nothing to load', () async {
      final SaveService service = SaveService(MemoryKeyValueStore());
      expect(await service.load(config), isNull);
    });

    test('saves and loads', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final GameState state = _busyState(config);
      expect(await SaveService(store).save(state), isTrue);
      final GameState? loaded = await SaveService(store).load(config);
      expect(loaded, isNotNull);
      _expectSame(loaded!, state);
    });

    test('writes the two slots alternately', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SaveService service = SaveService(store);
      final GameState state = GameState.initial(config);
      await service.save(state);
      expect(store.values.containsKey(SaveService.slotBKey), isTrue);
      expect(store.values.containsKey(SaveService.slotAKey), isFalse);
      await service.save(state);
      expect(store.values.containsKey(SaveService.slotAKey), isTrue);
    });

    test('the newest save wins', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SaveService service = SaveService(store);
      final GameState state = GameState.initial(config);
      for (int coins = 1; coins <= 5; coins++) {
        state.coins = coins.toDouble();
        await service.save(state);
      }
      final GameState? loaded = await SaveService(store).load(config);
      expect(loaded!.coins, 5);
    });

    test('a damaged newest slot falls back to the older one', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SaveService service = SaveService(store);
      final GameState state = GameState.initial(config);
      state.coins = 10;
      await service.save(state); // sequence 1 -> slot B
      state.coins = 20;
      await service.save(state); // sequence 2 -> slot A (newest)
      store.values[SaveService.slotAKey] = '{"v":1,"n":2,"c":1,"p":"broken"}';
      final GameState? loaded = await SaveService(store).load(config);
      expect(loaded!.coins, 10);
    });

    test('two damaged slots mean a fresh start, not a crash', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore(<String, String>{
        SaveService.slotAKey: 'not a save',
        SaveService.slotBKey: '',
      });
      expect(await SaveService(store).load(config), isNull);
    });

    test('saves after a load never overwrite the newest slot', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final GameState state = GameState.initial(config);
      final SaveService first = SaveService(store);
      state.coins = 1;
      await first.save(state); // B (n=1)
      state.coins = 2;
      await first.save(state); // A (n=2)

      final SaveService second = SaveService(store);
      final GameState? loaded = await second.load(config);
      expect(loaded!.coins, 2);
      state.coins = 3;
      await second.save(state); // must replace the OLDER slot (B, n=3)
      final SaveEnvelope? slotA = decodeEnvelope(store.values[SaveService.slotAKey]!);
      final SaveEnvelope? slotB = decodeEnvelope(store.values[SaveService.slotBKey]!);
      expect(slotA!.sequence, 2);
      expect(slotB!.sequence, 3);
      expect((await SaveService(store).load(config))!.coins, 3);
    });

    test('overlapping saves use different slots', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SaveService service = SaveService(store);
      final GameState one = GameState.initial(config)..coins = 1;
      final GameState two = GameState.initial(config)..coins = 2;
      await Future.wait(<Future<bool>>[service.save(one), service.save(two)]);
      expect(store.values.length, 2);
      expect((await SaveService(store).load(config))!.coins, 2);
    });

    test('a save from a newer app version is ignored', () async {
      final String payload = jsonEncode(GameState.initial(config).toJson());
      final MemoryKeyValueStore store = MemoryKeyValueStore(<String, String>{
        SaveService.slotAKey: jsonEncode(<String, Object?>{
          'v': kSaveVersion + 5,
          'n': 9,
          'c': checksum(payload),
          'p': payload,
        }),
      });
      expect(await SaveService(store).load(config), isNull);
    });

    test('a payload that is not a game object is ignored', () async {
      const String payload = '"just text"';
      final MemoryKeyValueStore store = MemoryKeyValueStore(<String, String>{
        SaveService.slotAKey: encodeEnvelope(sequence: 4, payload: payload),
      });
      expect(await SaveService(store).load(config), isNull);
    });

    test('a broken disk is reported, not mistaken for a new player', () async {
      final SaveService service = SaveService(_BrokenStore());
      await expectLater(service.load(config), throwsA(isA<SaveReadException>()));
      expect(await service.save(GameState.initial(config)), isFalse, reason: 'save never throws');
    });

    test('clear removes both slots', () async {
      final MemoryKeyValueStore store = MemoryKeyValueStore();
      final SaveService service = SaveService(store);
      await service.save(GameState.initial(config));
      await service.save(GameState.initial(config));
      await service.clear();
      expect(store.values, isEmpty);
      expect(await service.load(config), isNull);
    });
  });
}
