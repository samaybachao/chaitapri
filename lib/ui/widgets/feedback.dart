import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';

extension FormatContext on BuildContext {
  /// `2h 15m` / `2 घं 15 मि` in the current language.
  String duration(double seconds) {
    return formatDuration(
      seconds,
      hourUnit: t('unit_h'),
      minuteUnit: t('unit_m'),
      secondUnit: t('unit_s'),
    );
  }
}

/// The text to show when a rewarded ad did not give its reward; null when it did.
String? adProblemText(BuildContext context, AdOutcome outcome) {
  switch (outcome) {
    case AdOutcome.rewarded:
      return null;
    case AdOutcome.dismissed:
      return context.t('ad_dismissed');
    case AdOutcome.notReady:
      return context.t('ad_not_ready');
    case AdOutcome.unavailable:
      return context.t('ad_unavailable');
    case AdOutcome.failed:
      return context.t('ad_failed');
  }
}

/// Shows a short message at the bottom of the screen (replaces the current one).
void showToast(BuildContext context, String text) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// "+1.2K coins" toast for a paid reward.
void showCoinsToast(BuildContext context, double coins) {
  showToast(context, context.t('sem_coins', <String, Object>{'coins': '+${formatNumber(coins)}'}));
}

/// Toast for the end of a claim: the coins when paid, the ad problem otherwise.
void showClaimToast(BuildContext context, ClaimResult result) {
  if (result.paid) {
    showCoinsToast(context, result.coins);
    return;
  }
  final AdOutcome? outcome = result.outcome;
  if (outcome != null) {
    final String? problem = adProblemText(context, outcome);
    if (problem != null) {
      showToast(context, problem);
    }
  }
}
