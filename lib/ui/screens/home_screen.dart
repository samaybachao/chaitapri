import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/core/economy.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/dialogs/dialogs.dart';
import 'package:chai_tapri/ui/panels/daily_panel.dart';
import 'package:chai_tapri/ui/panels/menu_panel.dart';
import 'package:chai_tapri/ui/panels/upgrades_panel.dart';
import 'package:chai_tapri/ui/scene/stall_scene.dart';
import 'package:chai_tapri/ui/screens/settings_screen.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/common.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

/// The one main screen: coins on top, the stall, and the Upgrades / Menu / Daily tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _checkingPopups = false;
  bool _autoDailyDone = false;
  GameController? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      final GameController game = AppScope.read(context).game;
      _game = game;
      game.addListener(_checkPopups);
      WidgetsBinding.instance.addPostFrameCallback((Duration _) => _checkPopups());
    }
  }

  @override
  void dispose() {
    _game?.removeListener(_checkPopups);
    super.dispose();
  }

  /// Shows the dialogs that wait for the player: language (first start), welcome back
  /// (offline earnings). Opens the Daily tab once per session when a reward waits.
  Future<void> _checkPopups() async {
    if (_checkingPopups || !mounted) {
      return;
    }
    _checkingPopups = true;
    try {
      final AppServices services = AppScope.read(context);
      if (!services.settings.languageChosen) {
        await showLanguageDialog(context);
        if (!mounted) {
          return;
        }
      }
      if (services.game.hasPendingOffline) {
        await showWelcomeBackDialog(context);
        if (!mounted) {
          return;
        }
      }
      if (!_autoDailyDone && services.game.tutorialStep >= 3 && services.game.dailyAvailable) {
        _autoDailyDone = true;
        setState(() => _tab = 2);
      }
    } finally {
      _checkingPopups = false;
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.app;
    final GameController game = services.game;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double sceneHeight = (constraints.maxHeight * 0.36).clamp(120.0, 420.0);
            return Column(
              children: <Widget>[
                _TopBar(game: game, onSettings: _openSettings),
                _Banner(game: game),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: sceneHeight),
                  child: Center(
                    child: StallScene(onVipTap: () => showVipDialog(context)),
                  ),
                ),
                _Tabs(
                  game: game,
                  selected: _tab,
                  onSelected: (int tab) => setState(() => _tab = tab),
                ),
                Expanded(child: _panel()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _panel() {
    switch (_tab) {
      case 1:
        return const MenuPanel(key: ValueKey<int>(1));
      case 2:
        return const DailyPanel(key: ValueKey<int>(2));
      default:
        return const UpgradesPanel(key: ValueKey<int>(0));
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game, required this.onSettings});

  final GameController game;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CoinIcon(size: 28),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: game.coins,
                        builder: (BuildContext context, double coins, Widget? child) {
                          return Semantics(
                            label: context.t('sem_coins', <String, Object>{
                              'coins': formatNumber(coins),
                            }),
                            excludeSemantics: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatNumber(coins),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.chai,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                ListenableBuilder(
                  listenable: game,
                  builder: (BuildContext context, Widget? child) {
                    final EconomySnapshot snapshot = game.snapshot;
                    final String rate = snapshot.idleRate > 0
                        ? context.t('hud_per_sec', <String, Object>{
                            'rate': formatRate(snapshot.idleRate),
                          })
                        : context.t('hud_tap_to_earn');
                    final String tap = context.t('hud_tap_value', <String, Object>{
                      'coins': formatRate(snapshot.tapCoins),
                    });
                    return Text(
                      '$rate  ·  $tap',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    );
                  },
                ),
              ],
            ),
          ),
          _BoostButton(game: game),
          IconButton(
            onPressed: onSettings,
            tooltip: context.t('settings_title'),
            icon: const Icon(Icons.settings, color: AppColors.chai),
          ),
        ],
      ),
    );
  }
}

class _BoostButton extends StatefulWidget {
  const _BoostButton({required this.game});

  final GameController game;

  @override
  State<_BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<_BoostButton> {
  bool _busy = false;
  bool _prepared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepared) {
      _prepared = true;
      context.app.ads.prepare(AdPlacement.boost);
    }
  }

  Future<void> _watch() async {
    if (_busy) {
      return;
    }
    final String grantedText = context.t('boost_granted');
    setState(() => _busy = true);
    final AdOutcome outcome = await widget.game.watchAdForBoost();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    showToast(context, adProblemText(context, outcome) ?? grantedText);
  }

  @override
  Widget build(BuildContext context) {
    final GameController game = widget.game;
    final bool adsOn = context.app.ads.enabled;
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        final bool active = game.boostActive;
        if (!active && !(adsOn && game.canAddBoost)) {
          return const SizedBox.shrink();
        }
        final bool canTap = adsOn && game.canAddBoost && !_busy;
        final String label = _busy
            ? context.t('boost_loading')
            : (active
                  ? context.t('boost_active', <String, Object>{
                      'time': formatClock(game.boostSecondsLeft),
                    })
                  : context.t('boost_button'));
        return Material(
          color: active ? AppColors.saffron : AppColors.saffronDark,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: canTap ? _watch : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(active ? Icons.bolt : Icons.play_circle_fill, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      label,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One line of guidance under the top bar: VIP waiting, tutorial or a hint.
class _Banner extends StatelessWidget {
  const _Banner({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[game, game.coins]),
      builder: (BuildContext context, Widget? child) {
        final String? text = _text(context);
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: text == null ? const SizedBox(width: double.infinity) : _bar(context, text),
        );
      },
    );
  }

  bool get _showSkip => game.tutorialStep < 3 && !game.vipWaiting;

  String? _text(BuildContext context) {
    if (game.vipWaiting) {
      return context.t('vip_tap_hint');
    }
    switch (game.tutorialStep) {
      case 0:
        final int total = game.config.tutorialTapsStep1;
        final int count = game.state.totalTaps < total ? game.state.totalTaps : total;
        return context.t('tut_tap', <String, Object>{'count': count, 'total': total});
      case 1:
        return context.t('tut_buy');
      case 2:
        return context.t('tut_helper');
    }
    if (game.state.totalTaps == 0) {
      return null;
    }
    switch (game.snapshot.bottleneck) {
      case Bottleneck.production:
        return context.t('hint_production');
      case Bottleneck.customers:
        return context.t('hint_customers');
      case Bottleneck.balanced:
        break;
    }
    if (game.state.levels[game.economy.helperIndex] == 0 && !game.freeHelperRunning) {
      return context.t('hint_no_helper');
    }
    return null;
  }

  Widget _bar(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: game.vipWaiting ? AppColors.gold.withValues(alpha: 0.35) : AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: game.vipWaiting ? AppColors.gold : AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            game.vipWaiting ? Icons.star : Icons.lightbulb,
            size: 18,
            color: AppColors.saffronDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (_showSkip)
            TextButton(
              onPressed: game.skipTutorial,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(context.t('tut_skip')),
            ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.game, required this.selected, required this.onSelected});

  final GameController game;
  final int selected;
  final ValueChanged<int> onSelected;

  bool get _upgradeReady {
    for (int i = 0; i < game.state.levels.length; i++) {
      if (game.engine.canBuy(i, game.buyMode)) {
        return true;
      }
    }
    return false;
  }

  bool get _menuReady {
    final int next = game.engine.nextMenuToUnlock;
    return next >= 0 && game.engine.canUnlockMenu(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          decoration: BoxDecoration(
            color: AppColors.creamDark,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: <Widget>[
              _TabItem(
                icon: Icons.upgrade,
                label: context.t('tab_upgrades'),
                selected: selected == 0,
                badge: _upgradeReady,
                onTap: () => onSelected(0),
              ),
              _TabItem(
                icon: Icons.restaurant_menu,
                label: context.t('tab_menu'),
                selected: selected == 1,
                badge: _menuReady,
                onTap: () => onSelected(1),
              ),
              _TabItem(
                icon: Icons.card_giftcard,
                label: context.t('tab_daily'),
                selected: selected == 2,
                badge: game.dailyAvailable,
                onTap: () => onSelected(2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.chai : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: selected ? Colors.white : AppColors.chai),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.chai,
                    ),
                  ),
                ),
                if (badge) ...<Widget>[
                  const SizedBox(width: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.chili,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
