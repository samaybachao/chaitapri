import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/l10n/strings.dart';

import 'support/test_support.dart';

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

Set<String> placeholders(String text) {
  return _placeholder.allMatches(text).map((RegExpMatch m) => m.group(1) ?? '').toSet();
}

void main() {
  final Strings en = Strings.forLanguage('en');
  final Strings hi = Strings.forLanguage('hi');

  test('both languages have exactly the same keys', () {
    final Set<String> enKeys = en.keys.toSet();
    final Set<String> hiKeys = hi.keys.toSet();
    expect(enKeys.difference(hiKeys), isEmpty, reason: 'missing in Hindi');
    expect(hiKeys.difference(enKeys), isEmpty, reason: 'missing in English');
  });

  test('placeholders match between the languages', () {
    for (final String key in en.keys) {
      expect(placeholders(hi.t(key)), placeholders(en.t(key)), reason: key);
    }
  });

  test('no text is empty', () {
    for (final Strings strings in <Strings>[en, hi]) {
      for (final String key in strings.keys) {
        expect(strings.t(key).trim(), isNotEmpty, reason: '${strings.languageCode}/$key');
      }
    }
  });

  test('Hindi texts are really translated', () {
    // Texts that may stay equal in both languages.
    const Set<String> same = <String>{'buy_one', 'buy_ten', 'boost_active', 'hud_per_sec'};
    int untranslated = 0;
    for (final String key in en.keys) {
      if (!same.contains(key) && hi.t(key) == en.t(key)) {
        untranslated += 1;
      }
    }
    expect(untranslated, lessThanOrEqualTo(3));
  });

  test('t fills placeholders and survives unknown keys', () {
    expect(en.t('hud_per_sec', <String, Object>{'rate': '1.5'}), '1.5/sec');
    expect(en.t('no_such_key'), 'no_such_key');
    expect(hi.t('no_such_key'), 'no_such_key');
    expect(en.has('tab_menu'), isTrue);
    expect(en.has('no_such_key'), isFalse);
  });

  test('language selection', () {
    expect(languageForSystem('hi'), 'hi');
    expect(languageForSystem('en'), 'en');
    expect(languageForSystem('de'), 'en');
    expect(languageForSystem(null), 'en');
    expect(Strings.forLanguage('zz').languageCode, 'en');
  });

  test('every upgrade and menu item of the config has its texts', () {
    final config = loadTestConfig();
    for (final Strings strings in <Strings>[en, hi]) {
      for (final upgrade in config.upgrades) {
        for (final String suffix in <String>['', '_desc', '_effect']) {
          final String key = 'up_${upgrade.id}$suffix';
          expect(strings.has(key), isTrue, reason: '${strings.languageCode}/$key');
        }
        final Set<String> effect = placeholders(strings.t('up_${upgrade.id}_effect'));
        expect(effect, <String>{'from', 'to'});
      }
      for (final item in config.menu) {
        expect(strings.has('menu_${item.id}'), isTrue, reason: 'menu_${item.id}');
      }
    }
  });

  test('every text key used in the code exists', () {
    final RegExp use = RegExp(r"\bt\(\s*'([a-z0-9_]+)'");
    final List<String> missing = <String>[];
    for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final RegExpMatch match in use.allMatches(source)) {
        final String key = match.group(1) ?? '';
        if (!en.has(key)) {
          missing.add('${entity.path}: $key');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('every key is used somewhere (no dead texts)', () {
    final StringBuffer all = StringBuffer();
    for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart') && !entity.path.endsWith('strings.dart')) {
        all.write(entity.readAsStringSync());
      }
    }
    final String code = all.toString();
    // Keys built at run time ('up_$id', 'menu_$id', 'lang_$code', 'unit_h' ...) are found by prefix.
    const List<String> dynamicPrefixes = <String>['up_', 'menu_', 'lang_'];
    final List<String> unused = <String>[];
    for (final String key in en.keys) {
      if (dynamicPrefixes.any(key.startsWith) && !key.startsWith('menu_price') &&
          !key.startsWith('menu_time') && !key.startsWith('menu_in') &&
          !key.startsWith('menu_unlock') && !key.startsWith('menu_locked') &&
          !key.startsWith('lang_title')) {
        continue;
      }
      if (!code.contains("'$key'")) {
        unused.add(key);
      }
    }
    expect(unused, isEmpty, reason: 'remove these texts or use them');
  });
}
