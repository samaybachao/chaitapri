import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/services/analytics.dart';
import 'package:chai_tapri/services/haptics.dart';
import 'package:chai_tapri/services/links.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/state/settings_controller.dart';

/// Everything the screens need, created once at start-up (see `bootstrap`).
class AppServices {
  AppServices({
    required this.game,
    required this.settings,
    required this.ads,
    required this.links,
    required this.analytics,
    required this.haptics,
  });

  final GameController game;
  final SettingsController settings;
  final AdsService ads;
  final LinkOpener links;
  final Analytics analytics;
  final Haptics haptics;

  void dispose() {
    game.dispose();
    settings.dispose();
    ads.dispose();
  }
}
