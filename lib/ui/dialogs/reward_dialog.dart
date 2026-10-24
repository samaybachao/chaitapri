import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/services/ads_service.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/ad_button.dart';
import 'package:chai_tapri/ui/widgets/common.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

/// Pays a reward: [onCollect] gets `true` for the "2x with an ad" button.
typedef CollectCallback = Future<ClaimResult> Function(bool doubled);

/// A dialog with a coin amount and "Collect" / "Collect 2x" buttons. Used for the
/// welcome-back earnings and for the VIP tip.
class RewardDialog extends StatefulWidget {
  const RewardDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.coins,
    required this.collectLabel,
    required this.collectDoubleLabel,
    required this.placement,
    required this.onCollect,
    this.note,
  });

  final IconData icon;
  final String title;
  final String body;
  final double coins;
  final String collectLabel;
  final String collectDoubleLabel;
  final AdPlacement placement;
  final CollectCallback onCollect;

  /// Small extra line under the amount.
  final String? note;

  @override
  State<RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<RewardDialog> {
  bool _busy = false;
  bool _prepared = false;
  String? _problem;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepared) {
      _prepared = true;
      context.app.ads.prepare(widget.placement);
    }
  }

  Future<void> _collect(bool doubled) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final ClaimResult result = await widget.onCollect(doubled);
    if (!mounted) {
      return;
    }
    if (result.paid || result.outcome == null) {
      Navigator.of(context).pop(result);
      return;
    }
    final AdOutcome outcome = result.outcome ?? AdOutcome.failed;
    setState(() {
      _busy = false;
      _problem = adProblemText(context, outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool adsOn = context.app.ads.enabled;
    return AlertDialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: <Widget>[
          Icon(widget.icon, color: AppColors.saffronDark, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.body),
          const SizedBox(height: 12),
          Center(
            child: CoinAmount(
              text: formatNumber(widget.coins),
              iconSize: 30,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.chai,
              ),
            ),
          ),
          if (widget.note != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              widget.note ?? '',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (_problem != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _problem ?? '',
              style: const TextStyle(color: AppColors.chili, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: <Widget>[
        FilledButton(
          onPressed: _busy ? null : () => _collect(false),
          style: gameButtonStyle(minWidth: 120),
          child: Text(widget.collectLabel),
        ),
        if (adsOn)
          AdButton(
            label: widget.collectDoubleLabel,
            busy: _busy,
            onPressed: () => _collect(true),
          ),
      ],
    );
  }
}
