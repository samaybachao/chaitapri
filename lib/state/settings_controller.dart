import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:chai_tapri/l10n/strings.dart';
import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/key_value_store.dart';

/// The player's choices: language and vibration.
///
/// Stored apart from the game save, so "Reset progress" keeps them.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required KeyValueStore store,
    required Haptics haptics,
    String? systemLanguageCode,
  }) : _store = store,
       _haptics = haptics,
       _systemLanguage = languageForSystem(systemLanguageCode) {
    _strings = Strings.forLanguage(_systemLanguage);
  }

  static const String storageKey = 'settings';

  final KeyValueStore _store;
  final Haptics _haptics;
  final String _systemLanguage;

  late Strings _strings;
  String? _chosenLanguage;
  bool _vibration = true;

  /// Texts in the current language.
  Strings get strings => _strings;

  /// `en` or `hi`.
  String get languageCode => _strings.languageCode;

  /// False until the player picked a language (the first-start dialog).
  bool get languageChosen => _chosenLanguage != null;

  bool get vibration => _vibration;

  /// Reads the saved settings. Damaged data is ignored.
  Future<void> load() async {
    try {
      final String? raw = await _store.read(storageKey);
      if (raw == null) {
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final Object? language = decoded['lang'];
      if (language is String && kSupportedLanguages.contains(language)) {
        _chosenLanguage = language;
        _strings = Strings.forLanguage(language);
      }
      final Object? vibration = decoded['vibration'];
      if (vibration is bool) {
        _vibration = vibration;
      }
    } catch (error) {
      debugPrint('Ignoring unreadable settings: $error');
    }
    _haptics.enabled = _vibration;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!kSupportedLanguages.contains(code)) {
      return;
    }
    _chosenLanguage = code;
    _strings = Strings.forLanguage(code);
    notifyListeners();
    await _save();
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    _haptics.enabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final String raw = jsonEncode(<String, Object?>{
        'v': 1,
        'lang': _chosenLanguage,
        'vibration': _vibration,
      });
      await _store.write(storageKey, raw);
    } catch (error) {
      debugPrint('Saving settings failed: $error');
    }
  }
}
