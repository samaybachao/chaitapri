/// All texts of the game in English and Hindi.
///
/// Keys are plain snake_case names. `{name}` marks a value that is filled in by
/// [Strings.t]. `test/l10n_test.dart` checks that both languages have exactly the
/// same keys and placeholders, and that every key used in the code exists.
library;

/// Language codes the game can show.
const List<String> kSupportedLanguages = <String>['en', 'hi'];

/// The language used when the phone language is not supported.
const String kFallbackLanguage = 'en';

/// Picks the game language for a phone language code such as `hi` or `en`.
String languageForSystem(String? systemLanguageCode) {
  if (systemLanguageCode != null && kSupportedLanguages.contains(systemLanguageCode)) {
    return systemLanguageCode;
  }
  return kFallbackLanguage;
}

/// Texts of one language.
class Strings {
  const Strings._(this.languageCode, this._table);

  /// The texts for [languageCode] (`en` when the code is unknown).
  factory Strings.forLanguage(String languageCode) {
    if (languageCode == 'hi') {
      return const Strings._('hi', _hindi);
    }
    return const Strings._('en', _english);
  }

  final String languageCode;
  final Map<String, String> _table;

  /// The text for [key] with every `{name}` replaced by the matching value of [args].
  /// An unknown key is returned as is, so a mistake is visible and never crashes.
  String t(String key, [Map<String, Object>? args]) {
    String text = _table[key] ?? _english[key] ?? key;
    if (args != null) {
      args.forEach((String name, Object value) {
        text = text.replaceAll('{$name}', value.toString());
      });
    }
    return text;
  }

  /// True when [key] exists in this language.
  bool has(String key) => _table.containsKey(key);

  /// All keys (tests).
  Iterable<String> get keys => _table.keys;
}

/// English texts. This table is the reference: Hindi must have the same keys.
const Map<String, String> _english = <String, String>{
  // General
  'app_name': 'Chai Tapri Tycoon',
  'cancel': 'Cancel',
  'try_again': 'Try again',
  'unit_h': 'h',
  'unit_m': 'm',
  'unit_s': 's',

  // Top of the screen
  'hud_per_sec': '{rate}/sec',
  'hud_tap_value': 'Tap +{coins}',
  'hud_tap_to_earn': 'Tap the stall to earn',
  'boost_button': '2× income · 5 min',
  'boost_active': '2× · {time}',
  'boost_loading': 'Loading ad…',
  'boost_granted': '2× income is on!',

  // Tutorial and hints
  'tut_tap': 'Tap the stall to brew chai! ({count}/{total})',
  'tut_buy': 'Nice! Now buy your first upgrade below.',
  'tut_helper': 'Hire a helper. He keeps the stall earning even when you are away.',
  'tut_skip': 'Skip',
  'hint_production': 'Chai is brewing slowly. Upgrade the Chulha or the Kettle.',
  'hint_customers': 'Not enough customers. Upgrade the Seats or the Signboard.',
  'hint_no_helper': 'Hire a helper so the stall earns while you are away.',

  // Bottom panel
  'tab_upgrades': 'Upgrades',
  'tab_menu': 'Menu',
  'tab_daily': 'Daily',
  'buy_one': '×1',
  'buy_ten': '×10',
  'buy_max': 'MAX',
  'level_label': 'Lv {level}',
  'level_max': 'MAX',
  'tag_bottleneck': 'Bottleneck',

  // Upgrades
  'up_chulha': 'Chulha',
  'up_kettle': 'Kettle',
  'up_seats': 'Seats',
  'up_helper': 'Helper',
  'up_board': 'Signboard',
  'up_radio': 'Radio',
  'up_chulha_desc': 'Brews every cup faster',
  'up_kettle_desc': 'More cups in every batch',
  'up_seats_desc': 'More seats, more customers',
  'up_helper_desc': 'Runs the stall while you are away',
  'up_board_desc': 'A bright board pulls customers in',
  'up_radio_desc': 'Songs bring tips and VIP visits',
  'up_chulha_effect': 'Speed ×{from} → ×{to}',
  'up_kettle_effect': 'Cups per batch {from} → {to}',
  'up_seats_effect': 'Customers ×{from} → ×{to}',
  'up_board_effect': 'Customers ×{from} → ×{to}',
  'up_helper_effect': 'Earns while idle {from}% → {to}%',
  'up_radio_effect': 'Tips +{from}% → +{to}%',

  // Free helper
  'fh_title': 'Free helper',
  'fh_body': 'Watch a short ad and a helper runs your stall for {time}.',
  'fh_running': 'Helper is working: {time} left',
  'fh_cooldown': 'Next free helper in {time}',
  'fh_button': 'Watch ad',
  'fh_started': 'A helper is running your stall for {time}!',

  // Menu
  'menu_cutting': 'Cutting chai',
  'menu_masala': 'Masala chai',
  'menu_adrak': 'Adrak chai',
  'menu_kulhad': 'Kulhad chai',
  'menu_price': '{price} per cup',
  'menu_time': 'Brew time {time}',
  'menu_in': 'On the menu',
  'menu_unlock': 'Unlock',
  'menu_locked': 'Unlock {name} first',
  'soon_tag': 'Coming soon',
  'soon_title': 'Railway Station Stall',
  'soon_body': 'Your second stall arrives in the next update.',

  // Daily reward
  'daily_title': 'Daily reward',
  'daily_day': 'Day {day}',
  'daily_today': 'Today: {coins} coins',
  'daily_collect': 'Collect',
  'daily_collect_x2': 'Collect 2×',
  'daily_done': 'Collected! See you tomorrow.',
  'daily_hint': 'Open the game every day. Day 7 gives the biggest reward.',

  // Welcome back
  'wb_title': 'Welcome back!',
  'wb_body': 'In the {time} you were away, your stall earned:',
  'wb_capped': 'The stall works for up to {time} while you are away.',
  'wb_collect': 'Collect',
  'wb_collect_x2': 'Collect 2×',

  // VIP customer
  'vip_title': 'VIP customer!',
  'vip_body': 'A VIP loved your chai and left a big tip.',
  'vip_collect': 'Collect',
  'vip_collect_x2': 'Collect 2×',
  'vip_tap_hint': 'A VIP is here! Tap them',

  // Ads
  'ad_not_ready': 'The ad is not ready yet. Please try again in a moment.',
  'ad_failed': 'The ad could not be shown. Please try again later.',
  'ad_dismissed': 'Watch the whole ad to get the reward.',
  'ad_unavailable': 'Ads are not available right now.',

  // Language
  'lang_title': 'Choose your language',
  'lang_en': 'English',
  'lang_hi': 'हिन्दी',

  // Settings
  'settings_title': 'Settings',
  'set_language': 'Language',
  'set_vibration': 'Vibration',
  'set_privacy_policy': 'Privacy policy',
  'set_privacy_options': 'Ad privacy choices',
  'set_rate': 'Rate this game',
  'set_contact': 'Contact support',
  'set_reset': 'Reset progress',
  'reset_title': 'Reset progress?',
  'reset_body':
      'All your coins, upgrades and menu items will be deleted. This cannot be undone.',
  'reset_confirm': 'Delete everything',
  'set_version': 'Version {version}',
  'set_credits': 'Made with love by {name}',
  'link_failed': 'Could not open the link.',

  // Start-up problems
  'boot_error_title': 'Something went wrong',
  'boot_error_body': 'The game could not start. Please try again.',

  // Screen reader labels
  'sem_scene': 'Chai stall. Tap to brew chai.',
  'sem_coins': '{coins} coins',
};

/// Hindi texts.
const Map<String, String> _hindi = <String, String>{
  // General
  'app_name': 'चाय टपरी टाइकून',
  'cancel': 'रद्द करें',
  'try_again': 'फिर कोशिश करें',
  'unit_h': ' घं',
  'unit_m': ' मि',
  'unit_s': ' से',

  // Top of the screen
  'hud_per_sec': '{rate}/सेकंड',
  'hud_tap_value': 'टैप +{coins}',
  'hud_tap_to_earn': 'कमाने के लिए स्टॉल पर टैप करें',
  'boost_button': '2× कमाई · 5 मिनट',
  'boost_active': '2× · {time}',
  'boost_loading': 'विज्ञापन लोड हो रहा है…',
  'boost_granted': '2× कमाई चालू!',

  // Tutorial and hints
  'tut_tap': 'चाय बनाने के लिए स्टॉल पर टैप करें! ({count}/{total})',
  'tut_buy': 'बढ़िया! अब नीचे से अपना पहला अपग्रेड खरीदें।',
  'tut_helper': 'एक हेल्पर रखें। आपके जाने के बाद भी स्टॉल कमाता रहेगा।',
  'tut_skip': 'छोड़ें',
  'hint_production': 'चाय धीरे बन रही है। चूल्हा या केतली अपग्रेड करें।',
  'hint_customers': 'ग्राहक कम हैं। बैठने की जगह या बोर्ड अपग्रेड करें।',
  'hint_no_helper': 'हेल्पर रखें, ताकि आपके जाने पर भी स्टॉल कमाए।',

  // Bottom panel
  'tab_upgrades': 'अपग्रेड',
  'tab_menu': 'मेन्यू',
  'tab_daily': 'रोज़ाना',
  'buy_one': '×1',
  'buy_ten': '×10',
  'buy_max': 'मैक्स',
  'level_label': 'स्तर {level}',
  'level_max': 'मैक्स',
  'tag_bottleneck': 'रुकावट',

  // Upgrades
  'up_chulha': 'चूल्हा',
  'up_kettle': 'केतली',
  'up_seats': 'बैठने की जगह',
  'up_helper': 'हेल्पर',
  'up_board': 'बोर्ड',
  'up_radio': 'रेडियो',
  'up_chulha_desc': 'हर कप जल्दी बनता है',
  'up_kettle_desc': 'हर बार ज़्यादा कप बनते हैं',
  'up_seats_desc': 'ज़्यादा जगह, ज़्यादा ग्राहक',
  'up_helper_desc': 'आपके न होने पर भी स्टॉल चलाता है',
  'up_board_desc': 'चमकदार बोर्ड ग्राहकों को खींचता है',
  'up_radio_desc': 'गानों से टिप और VIP ग्राहक बढ़ते हैं',
  'up_chulha_effect': 'रफ़्तार ×{from} → ×{to}',
  'up_kettle_effect': 'हर बार कप {from} → {to}',
  'up_seats_effect': 'ग्राहक ×{from} → ×{to}',
  'up_board_effect': 'ग्राहक ×{from} → ×{to}',
  'up_helper_effect': 'खाली समय में कमाई {from}% → {to}%',
  'up_radio_effect': 'टिप +{from}% → +{to}%',

  // Free helper
  'fh_title': 'मुफ़्त हेल्पर',
  'fh_body': 'छोटा विज्ञापन देखें, {time} तक हेल्पर आपका स्टॉल चलाएगा।',
  'fh_running': 'हेल्पर काम कर रहा है: {time} बाकी',
  'fh_cooldown': 'अगला मुफ़्त हेल्पर {time} में',
  'fh_button': 'विज्ञापन देखें',
  'fh_started': '{time} के लिए हेल्पर आपका स्टॉल चला रहा है!',

  // Menu
  'menu_cutting': 'कटिंग चाय',
  'menu_masala': 'मसाला चाय',
  'menu_adrak': 'अदरक चाय',
  'menu_kulhad': 'कुल्हड़ चाय',
  'menu_price': '{price} प्रति कप',
  'menu_time': 'बनने का समय {time}',
  'menu_in': 'मेन्यू में है',
  'menu_unlock': 'खोलें',
  'menu_locked': 'पहले {name} खोलें',
  'soon_tag': 'जल्द आ रहा है',
  'soon_title': 'रेलवे स्टेशन स्टॉल',
  'soon_body': 'आपका दूसरा स्टॉल अगले अपडेट में आएगा।',

  // Daily reward
  'daily_title': 'रोज़ का इनाम',
  'daily_day': 'दिन {day}',
  'daily_today': 'आज: {coins} सिक्के',
  'daily_collect': 'इकट्ठा करें',
  'daily_collect_x2': '2× पाएँ',
  'daily_done': 'मिल गया! कल फिर मिलेंगे।',
  'daily_hint': 'रोज़ खेलें। सातवें दिन सबसे बड़ा इनाम मिलता है।',

  // Welcome back
  'wb_title': 'वापस आने पर स्वागत है!',
  'wb_body': 'आपके {time} बाहर रहने पर स्टॉल ने कमाए:',
  'wb_capped': 'आपके पीछे स्टॉल ज़्यादा से ज़्यादा {time} चलता है।',
  'wb_collect': 'इकट्ठा करें',
  'wb_collect_x2': '2× पाएँ',

  // VIP customer
  'vip_title': 'VIP ग्राहक!',
  'vip_body': 'VIP ग्राहक को आपकी चाय पसंद आई और उसने बड़ी टिप दी।',
  'vip_collect': 'इकट्ठा करें',
  'vip_collect_x2': '2× पाएँ',
  'vip_tap_hint': 'VIP आए हैं! उन पर टैप करें',

  // Ads
  'ad_not_ready': 'विज्ञापन अभी तैयार नहीं है। थोड़ी देर में फिर कोशिश करें।',
  'ad_failed': 'विज्ञापन नहीं दिखाया जा सका। बाद में फिर कोशिश करें।',
  'ad_dismissed': 'इनाम के लिए पूरा विज्ञापन देखें।',
  'ad_unavailable': 'विज्ञापन अभी उपलब्ध नहीं हैं।',

  // Language
  'lang_title': 'अपनी भाषा चुनें',
  'lang_en': 'English',
  'lang_hi': 'हिन्दी',

  // Settings
  'settings_title': 'सेटिंग्स',
  'set_language': 'भाषा',
  'set_vibration': 'वाइब्रेशन',
  'set_privacy_policy': 'गोपनीयता नीति',
  'set_privacy_options': 'विज्ञापन गोपनीयता विकल्प',
  'set_rate': 'इस गेम को रेट करें',
  'set_contact': 'सहायता से संपर्क करें',
  'set_reset': 'प्रगति रीसेट करें',
  'reset_title': 'प्रगति रीसेट करें?',
  'reset_body':
      'आपके सारे सिक्के, अपग्रेड और मेन्यू मिट जाएँगे। इसे वापस नहीं किया जा सकता।',
  'reset_confirm': 'सब कुछ मिटाएँ',
  'set_version': 'वर्ज़न {version}',
  'set_credits': '{name} द्वारा प्यार से बनाया गया',
  'link_failed': 'लिंक नहीं खुल सका।',

  // Start-up problems
  'boot_error_title': 'कुछ गड़बड़ हो गई',
  'boot_error_body': 'गेम शुरू नहीं हो सका। कृपया फिर कोशिश करें।',

  // Screen reader labels
  'sem_scene': 'चाय का स्टॉल। चाय बनाने के लिए टैप करें।',
  'sem_coins': '{coins} सिक्के',
};
