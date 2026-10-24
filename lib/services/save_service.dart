import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/core/save_codec.dart';
import 'package:chai_tapri/services/key_value_store.dart';

/// The storage could not be read at all. This is different from "there is no save":
/// starting a new game now would overwrite the player's real progress, so the
/// start-up shows an error with a retry button instead.
class SaveReadException implements Exception {
  const SaveReadException(this.message);

  final String message;

  @override
  String toString() => 'SaveReadException: $message';
}

/// Stores the game in two alternating slots.
///
/// A save is written to the slot that does NOT hold the newest save, so a crash or
/// power loss while writing can only damage the older copy. Every slot is
/// checksummed; on load the newest slot that is intact wins.
class SaveService {
  SaveService(this._store);

  static const String slotAKey = 'save_a';
  static const String slotBKey = 'save_b';

  final KeyValueStore _store;
  int _sequence = 0;

  /// Loads the newest intact save. Returns null for a new player (or when both
  /// slots hold damaged data). Throws [SaveReadException] when the storage itself
  /// failed and no slot could be read.
  Future<GameState?> load(GameConfig config) async {
    final List<_Candidate> candidates = <_Candidate>[];
    int storageFailures = 0;
    for (final String key in <String>[slotAKey, slotBKey]) {
      String? raw;
      try {
        raw = await _store.read(key);
      } catch (error) {
        debugPrint('Could not read save slot $key: $error');
        storageFailures += 1;
        continue;
      }
      final _Candidate? candidate = _parseSlot(key, raw, config);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    if (candidates.isEmpty) {
      if (storageFailures > 0) {
        throw const SaveReadException('The saved game could not be read.');
      }
      return null;
    }
    candidates.sort((_Candidate a, _Candidate b) => b.sequence.compareTo(a.sequence));
    _sequence = candidates.first.sequence;
    return candidates.first.state;
  }

  /// Writes [state]. Never throws: a failed save must not stop the game.
  Future<bool> save(GameState state) async {
    try {
      final String payload = jsonEncode(state.toJson());
      _sequence += 1;
      final int next = _sequence;
      final String key = next.isEven ? slotAKey : slotBKey;
      await _store.write(key, encodeEnvelope(sequence: next, payload: payload));
      return true;
    } catch (error, stack) {
      debugPrint('Save failed: $error\n$stack');
      return false;
    }
  }

  /// Deletes both slots (tests and "Reset progress" do not need this, but it keeps the
  /// door open for a "delete my data" feature).
  Future<void> clear() async {
    await _store.remove(slotAKey);
    await _store.remove(slotBKey);
    _sequence = 0;
  }

  _Candidate? _parseSlot(String key, String? raw, GameConfig config) {
    try {
      if (raw == null) {
        return null;
      }
      final SaveEnvelope? envelope = decodeEnvelope(raw);
      if (envelope == null) {
        return null;
      }
      final Object? decoded = jsonDecode(envelope.payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Map<String, dynamic>? current = migrateSave(envelope.version, decoded);
      if (current == null) {
        return null;
      }
      return _Candidate(envelope.sequence, GameState.fromJson(current, config));
    } catch (error) {
      debugPrint('Ignoring unreadable save slot $key: $error');
      return null;
    }
  }
}

class _Candidate {
  const _Candidate(this.sequence, this.state);

  final int sequence;
  final GameState state;
}
