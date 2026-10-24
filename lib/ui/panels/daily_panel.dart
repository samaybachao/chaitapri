import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/core/engine.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/ad_button.dart';
import 'package:chai_tapri/ui/widgets/common.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

/// The 7-day login calendar.
class DailyPanel extends StatefulWidget {
  const DailyPanel({super.key});

  @override
  State<DailyPanel> createState() => _DailyPanelState();
}

class _DailyPanelState extends State<DailyPanel> {
  bool _busy = false;
  bool _prepared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepared) {
      _prepared = true;
      context.app.ads.prepare(AdPlacement.dailyDouble);
    }
  }

  Future<void> _collect({required bool doubled}) async {
    final GameController game = context.app.game;
    setState(() => _busy = true);
    final ClaimResult result = await game.collectDaily(doubleWithAd: doubled);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    showClaimToast(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final GameController game = context.app.game;
    final bool adsOn = context.app.ads.enabled;
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        final DailyInfo info = game.dailyInfo;
        final List<Widget> tiles = <Widget>[];
        for (int day = 1; day <= 7; day++) {
          tiles.add(
            Expanded(
              child: _DayTile(
                day: day,
                claimed: day <= info.claimedThrough,
                today: day == info.day,
                canClaim: info.canClaim,
                reward: day == info.day ? info.reward : game.engine.dailyReward(day),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: <Widget>[
            GameCard(
              highlight: info.canClaim,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.card_giftcard, color: AppColors.saffronDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t('daily_title'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: tiles),
                  const SizedBox(height: 12),
                  if (info.canClaim) ...<Widget>[
                    Row(
                      children: <Widget>[
                        const CoinIcon(size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.t('daily_today', <String, Object>{
                              'coins': formatNumber(info.reward),
                            }),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _collect(doubled: false),
                            style: gameButtonStyle(),
                            child: Text(context.t('daily_collect')),
                          ),
                        ),
                        if (adsOn) ...<Widget>[
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdButton(
                              label: context.t('daily_collect_x2'),
                              busy: _busy,
                              onPressed: () => _collect(doubled: true),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else
                    Row(
                      children: <Widget>[
                        const Icon(Icons.check_circle, color: AppColors.leaf),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('daily_done'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.t('daily_hint'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.claimed,
    required this.today,
    required this.canClaim,
    required this.reward,
  });

  final int day;
  final bool claimed;
  final bool today;
  final bool canClaim;
  final double reward;

  @override
  Widget build(BuildContext context) {
    final bool active = today && canClaim;
    final Color background = claimed
        ? AppColors.leaf.withValues(alpha: 0.15)
        : (active ? AppColors.saffron.withValues(alpha: 0.25) : AppColors.cream);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.saffron : AppColors.line,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.t('daily_day', <String, Object>{'day': day}),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 4),
          if (claimed)
            const Icon(Icons.check_circle, color: AppColors.leaf, size: 22)
          else
            Icon(
              day == 7 ? Icons.emoji_events : Icons.monetization_on,
              color: day == 7 ? AppColors.saffronDark : AppColors.gold,
              size: 22,
            ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatNumber(reward),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
