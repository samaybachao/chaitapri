import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/services/admob_ads_service.dart';
import 'package:chai_tapri/services/ads_config.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/services/analytics.dart';
import 'package:chai_tapri/services/clock.dart';
import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/key_value_store.dart';
import 'package:chai_tapri/services/links.dart';
import 'package:chai_tapri/services/save_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/state/settings_controller.dart';

/// Path of the balance file (declared in pubspec.yaml).
const String kConfigAsset = 'assets/config/game_config.json';

/// Loads the game data, the save and the settings and starts the game.
///
/// Every parameter is optional; tests pass fakes for the parts they control.
/// Throws when the game cannot start (missing or damaged data, unreadable storage);
/// the app then shows an error screen with a retry button.
Future<AppServices> bootstrap({
  KeyValueStore? store,
  Clock? clock,
  AdsService? ads,
  LinkOpener? links,
  Analytics? analytics,
  AssetBundle? bundle,
  bool runLoop = true,
}) async {
  final KeyValueStore storage = store ?? PrefsKeyValueStore();
  final Clock time = clock ?? const SystemClock();
  final AssetBundle assets = bundle ?? rootBundle;

  final GameConfig config = GameConfig.parse(await assets.loadString(kConfigAsset));

  final Haptics haptics = Haptics();
  final SettingsController settings = SettingsController(
    store: storage,
    haptics: haptics,
    systemLanguageCode: PlatformDispatcher.instance.locale.languageCode,
  );
  await settings.load();

  final SaveService saves = SaveService(storage);
  final GameState? saved = await _loadWithRetry(saves, config);
  final GameState state = saved ?? GameState.initial(config, nowMs: time.nowMs());

  final AdsService adsService = ads ?? _createAds();
  final Analytics log = analytics ?? const DebugAnalytics();
  final GameController game = GameController(
    engine: GameEngine(config: config, state: state),
    saveService: saves,
    ads: adsService,
    clock: time,
    analytics: log,
    haptics: haptics,
  );
  await game.start(runLoop: runLoop);

  return AppServices(
    game: game,
    settings: settings,
    ads: adsService,
    links: links ?? UrlLauncherLinks(),
    analytics: log,
    haptics: haptics,
  );
}

/// One more try when the storage fails once (it can be busy right after boot).
Future<GameState?> _loadWithRetry(SaveService saves, GameConfig config) async {
  try {
    return await saves.load(config);
  } on SaveReadException {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return saves.load(config);
  }
}

/// Real ads on Android phones with at least one configured ad unit; otherwise none
/// (desktop and web runs, builds without ad units).
AdsService _createAds() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return NoAdsService();
  }
  final AdsConfig config = AdsConfig.fromEnvironment();
  if (!config.hasAnyUnit) {
    return NoAdsService();
  }
  return AdMobAdsService(config: config);
}
