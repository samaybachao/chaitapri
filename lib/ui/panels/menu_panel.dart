import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/common.dart';

/// The chai types the player can sell, plus a teaser for the next update.
class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController game = context.app.game;
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        final GameConfig config = game.config;
        final int next = game.engine.nextMenuToUnlock;
        final List<Widget> children = <Widget>[];
        for (int i = 0; i < config.menu.length; i++) {
          children.add(_MenuRow(game: game, index: i, isNext: i == next));
        }
        children.add(const _SoonCard());
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: children,
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.game, required this.index, required this.isNext});

  final GameController game;
  final int index;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final MenuItemDef item = game.config.menu[index];
    final bool unlocked = game.state.unlocked[index];
    final double brewSeconds = game.economy.itemBrewSeconds(index, game.state.levels[game.economy.chulhaIndex]);
    final String name = context.t('menu_${item.id}');

    Widget trailing;
    if (unlocked) {
      trailing = TagLabel(text: context.t('menu_in'), color: AppColors.leaf);
    } else if (isNext) {
      trailing = FilledButton(
        onPressed: game.engine.canUnlockMenu(index) ? () => game.unlockMenu(index) : null,
        style: gameButtonStyle(minWidth: 84),
        child: CoinAmount(
          text: formatNumber(item.unlockCost),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      );
    } else {
      trailing = const Icon(Icons.lock, color: AppColors.disabled);
    }

    String? lockedHint;
    if (!unlocked && !isNext && index > 0) {
      lockedHint = context.t('menu_locked', <String, Object>{
        'name': context.t('menu_${game.config.menu[index - 1].id}'),
      });
    }

    return GameCard(
      child: Row(
        children: <Widget>[
          IconBadge(
            icon: Icons.local_cafe,
            color: unlocked ? AppColors.chai : AppColors.disabled,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: unlocked || isNext ? AppColors.ink : AppColors.muted,
                  ),
                ),
                Text(
                  context.t('menu_price', <String, Object>{'price': formatRate(item.price)}),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  context.t('menu_time', <String, Object>{
                    'time': '${formatFactor(brewSeconds)}${context.t('unit_s')}',
                  }),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (lockedHint != null)
                  Text(
                    lockedHint,
                    style: const TextStyle(
                      color: AppColors.chili,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _SoonCard extends StatelessWidget {
  const _SoonCard();

  @override
  Widget build(BuildContext context) {
    return GameCard(
      child: Row(
        children: <Widget>[
          const IconBadge(icon: Icons.train, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      context.t('soon_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                    TagLabel(text: context.t('soon_tag'), color: AppColors.saffronDark),
                  ],
                ),
                Text(
                  context.t('soon_body'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
