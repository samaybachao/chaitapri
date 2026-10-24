import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/l10n/strings.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/dialogs/reward_dialog.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

/// First start: the player picks English or Hindi. Not dismissible by tapping outside;
/// the back button simply keeps the default language.
Future<void> showLanguageDialog(BuildContext context) async {
  final AppServices services = AppScope.read(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final Strings tr = services.settings.strings;
      return AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${Strings.forLanguage('en').t('lang_title')} / ${Strings.forLanguage('hi').t('lang_title')}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String code in kSupportedLanguages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: gameButtonStyle(
                      color: code == tr.languageCode ? AppColors.chai : AppColors.leaf,
                    ),
                    onPressed: () {
                      services.settings.setLanguage(code);
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(Strings.forLanguage(code).t('lang_$code')),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  // Back button: make the shown default language the chosen one.
  if (!services.settings.languageChosen) {
    await services.settings.setLanguage(services.settings.languageCode);
  }
}

/// Welcome back: the offline earnings wait for "Collect". Closing the dialog with the
/// back button collects them too, so nothing is ever lost.
Future<void> showWelcomeBackDialog(BuildContext context) async {
  final GameController game = AppScope.read(context).game;
  if (!game.hasPendingOffline) {
    return;
  }
  final double coins = game.pendingOfflineCoins;
  final double away = game.pendingOfflineSeconds;
  final bool capped = game.pendingOfflineCapped;
  final ClaimResult? result = await showDialog<ClaimResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return RewardDialog(
        icon: Icons.wb_sunny,
        title: dialogContext.t('wb_title'),
        body: dialogContext.t('wb_body', <String, Object>{'time': dialogContext.duration(away)}),
        coins: coins,
        note: capped
            ? dialogContext.t('wb_capped', <String, Object>{
                'time': dialogContext.duration(game.config.offlineCapSeconds),
              })
            : null,
        collectLabel: dialogContext.t('wb_collect'),
        collectDoubleLabel: dialogContext.t('wb_collect_x2'),
        placement: AdPlacement.offlineDouble,
        onCollect: (bool doubled) => game.collectOffline(doubleWithAd: doubled),
      );
    },
  );
  final ClaimResult? paid =
      result ?? (game.hasPendingOffline ? await game.collectOffline() : null);
  if (paid != null && paid.paid && context.mounted) {
    showCoinsToast(context, paid.coins);
  }
}

/// A VIP customer was tapped: show the tip. Closing with the back button collects it.
Future<void> showVipDialog(BuildContext context) async {
  final GameController game = AppScope.read(context).game;
  final double? tip = game.engageVip();
  if (tip == null) {
    return;
  }
  final ClaimResult? result = await showDialog<ClaimResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return RewardDialog(
        icon: Icons.star,
        title: dialogContext.t('vip_title'),
        body: dialogContext.t('vip_body'),
        coins: tip,
        collectLabel: dialogContext.t('vip_collect'),
        collectDoubleLabel: dialogContext.t('vip_collect_x2'),
        placement: AdPlacement.vipDouble,
        onCollect: (bool doubled) => game.collectVip(doubleWithAd: doubled),
      );
    },
  );
  final ClaimResult paid = result ?? await game.collectVip();
  if (paid.paid && context.mounted) {
    showCoinsToast(context, paid.coins);
  }
}

/// "Reset progress?" Returns true when the player confirmed.
Future<bool> showResetDialog(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dialogContext.t('reset_title'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(dialogContext.t('reset_body')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('cancel')),
          ),
          FilledButton(
            style: gameButtonStyle(color: AppColors.chili),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('reset_confirm')),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
