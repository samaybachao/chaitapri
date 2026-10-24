import 'package:shared_preferences/shared_preferences.dart';

/// Tiny string storage. The game only needs this, so tests can swap in memory.
abstract class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Real storage: Android SharedPreferences (included in the player's Google backup).
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) {
    return _prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) {
    return _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) {
    return _prefs.remove(key);
  }
}

/// In-memory storage for tests.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial])
    : values = initial ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
