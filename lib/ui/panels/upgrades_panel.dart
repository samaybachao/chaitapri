import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/economy.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/ad_button.dart';
import 'package:chai_tapri/ui/widgets/common.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

IconData _iconFor(String id) {
  switch (id) {
    case UpgradeIds.chulha:
      return Icons.local_fire_department;
    case UpgradeIds.kettle:
      return Icons.coffee;
    case UpgradeIds.seats:
      return Icons.event_seat;
    case UpgradeIds.helper:
      return Icons.person;
    case UpgradeIds.board:
      return Icons.storefront;
    case UpgradeIds.radio:
      return Icons.radio;
  }
  return Icons.star;
}

/// The list of upgrades with the buy-mode switch and the free-helper offer.
class UpgradesPanel extends StatelessWidget {
  const UpgradesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController game = context.app.game;
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        // In MAX mode the number of levels (and the price) follows the coins.
        if (game.buyMode == BuyMode.max) {
          return ValueListenableBuilder<double>(
            valueListenable: game.coins,
            builder: (BuildContext context, double coins, Widget? child) => _list(context, game),
          );
        }
        return _list(context, game);
      },
    );
  }

  Widget _list(BuildContext context, GameController game) {
    final GameConfig config = game.config;
    final Bottleneck bottleneck = game.snapshot.bottleneck;
    final int helperIndex = game.economy.helperIndex;
    final List<Widget> children = <Widget>[
      _BuyModeSwitch(game: game),
      const SizedBox(height: 8),
    ];
    if (game.state.levels[helperIndex] == 0 && context.app.ads.enabled) {
      children.add(const FreeHelperCard());
    }
    for (int i = 0; i < config.upgrades.length; i++) {
      final String id = config.upgrades[i].id;
      final bool isBottleneck =
          (bottleneck == Bottleneck.production &&
              (id == UpgradeIds.chulha || id == UpgradeIds.kettle)) ||
          (bottleneck == Bottleneck.customers && (id == UpgradeIds.seats || id == UpgradeIds.board));
      final int step = game.tutorialStep;
      final bool tutorialTarget =
          (step == 1 && i == 0) || (step == 2 && i == helperIndex);
      children.add(
        _UpgradeRow(
          game: game,
          index: i,
          bottleneck: isBottleneck && game.tutorialStep >= 3,
          highlight: tutorialTarget,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: children,
    );
  }
}

class _BuyModeSwitch extends StatelessWidget {
  const _BuyModeSwitch({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BuyMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.chai,
        selectedBackgroundColor: AppColors.chai,
        selectedForegroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      segments: <ButtonSegment<BuyMode>>[
        ButtonSegment<BuyMode>(value: BuyMode.one, label: Text(context.t('buy_one'))),
        ButtonSegment<BuyMode>(value: BuyMode.ten, label: Text(context.t('buy_ten'))),
        ButtonSegment<BuyMode>(value: BuyMode.max, label: Text(context.t('buy_max'))),
      ],
      selected: <BuyMode>{game.buyMode},
      onSelectionChanged: (Set<BuyMode> picked) {
        if (picked.isNotEmpty) {
          game.setBuyMode(picked.first);
        }
      },
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.game,
    required this.index,
    required this.bottleneck,
    required this.highlight,
  });

  final GameController game;
  final int index;
  final bool bottleneck;
  final bool highlight;

  String _effectText(BuildContext context, String id, int level, int count) {
    final Economy economy = game.economy;
    final double from = economy.effectValue(index, level);
    final double to = economy.effectValue(index, level + count);
    final bool percent = id == UpgradeIds.helper || id == UpgradeIds.radio;
    final String fromText = percent ? formatPercent(from) : formatFactor(from);
    final String toText = percent ? formatPercent(to) : formatFactor(to);
    return context.t('up_${id}_effect', <String, Object>{'from': fromText, 'to': toText});
  }

  @override
  Widget build(BuildContext context) {
    final String id = game.config.upgrades[index].id;
    final int level = game.state.levels[index];
    final bool maxed = level >= game.config.maxLevel;
    final int count = game.engine.plannedCount(index, game.buyMode);
    final bool canBuy = game.engine.canBuy(index, game.buyMode);
    final double cost = game.engine.plannedCost(index, game.buyMode);

    return GameCard(
      highlight: highlight,
      child: Row(
        children: <Widget>[
          IconBadge(icon: _iconFor(id)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      context.t('up_$id'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      maxed
                          ? context.t('level_max')
                          : context.t('level_label', <String, Object>{'level': level}),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    if (bottleneck) TagLabel(text: context.t('tag_bottleneck')),
                  ],
                ),
                Text(
                  context.t('up_${id}_desc'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (!maxed)
                  Text(
                    _effectText(context, id, level, count),
                    style: const TextStyle(
                      color: AppColors.leafDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canBuy ? () => game.buyUpgrade(index) : null,
            style: gameButtonStyle(minWidth: 84),
            child: maxed
                ? Text(context.t('level_max'))
                : CoinAmount(
                    text: formatNumber(cost),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Watch an ad, get a helper for ten minutes".
class FreeHelperCard extends StatefulWidget {
  const FreeHelperCard({super.key});

  @override
  State<FreeHelperCard> createState() => _FreeHelperCardState();
}

class _FreeHelperCardState extends State<FreeHelperCard> {
  Timer? _timer;
  bool _busy = false;
  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepared) {
      _prepared = true;
      context.app.ads.prepare(AdPlacement.freeHelper);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _watch() async {
    final GameController game = context.app.game;
    final String startedText = context.t('fh_started', <String, Object>{
      'time': context.duration(game.config.freeHelperSeconds),
    });
    setState(() => _busy = true);
    final AdOutcome outcome = await game.watchAdForFreeHelper();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    final String? problem = adProblemText(context, outcome);
    showToast(context, problem ?? startedText);
  }

  @override
  Widget build(BuildContext context) {
    final GameController game = context.app.game;
    final bool running = game.freeHelperRunning;
    final bool offered = game.freeHelperOffered;
    final double cooldown = game.freeHelperCooldownSeconds;

    String body;
    if (running) {
      body = context.t('fh_running', <String, Object>{
        'time': context.duration(game.freeHelperSecondsLeft),
      });
    } else if (offered) {
      body = context.t('fh_body', <String, Object>{
        'time': context.duration(game.config.freeHelperSeconds),
      });
    } else {
      body = context.t('fh_cooldown', <String, Object>{'time': context.duration(cooldown)});
    }

    return GameCard(
      highlight: game.tutorialStep == 2 && offered,
      child: Row(
        children: <Widget>[
          const IconBadge(icon: Icons.volunteer_activism, color: AppColors.leaf),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.t('fh_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (offered) ...<Widget>[
            const SizedBox(width: 8),
            AdButton(label: context.t('fh_button'), busy: _busy, onPressed: _watch),
          ],
        ],
      ),
    );
  }
}
