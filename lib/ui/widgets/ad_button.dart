import 'package:flutter/material.dart';

import 'package:chai_tapri/ui/theme.dart';

/// A filled button with a "play" symbol for actions that show a rewarded ad.
class AdButton extends StatelessWidget {
  const AdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a small spinner and disables the button (an ad is loading or showing).
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget icon = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        : const Icon(Icons.play_circle_fill, size: 18);
    final Widget button = FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: gameButtonStyle(color: AppColors.saffronDark),
      icon: icon,
      label: Text(label, maxLines: 2, textAlign: TextAlign.center),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
