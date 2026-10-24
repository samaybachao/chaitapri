import 'package:flutter/material.dart';

import 'package:chai_tapri/ui/theme.dart';

/// A gold coin symbol.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.monetization_on, color: AppColors.gold, size: size);
  }
}

/// A cream card with a thin border; the base of every row in the panels.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.highlight = false,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;

  /// A strong outline (used for the thing the tutorial wants the player to press).
  final bool highlight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.saffron : AppColors.line,
          width: highlight ? 2.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// A round icon badge used at the start of a row.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.saffron,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// A small coloured label such as "Bottleneck" or "Coming soon".
class TagLabel extends StatelessWidget {
  const TagLabel({super.key, required this.text, this.color = AppColors.chili});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Coin symbol followed by an amount text, for buttons and labels.
class CoinAmount extends StatelessWidget {
  const CoinAmount({
    super.key,
    required this.text,
    this.style,
    this.iconSize = 16,
  });

  final String text;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CoinIcon(size: iconSize),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Fades a coloured outline in and out; draws the eye to the next thing to press.
class PulseHighlight extends StatefulWidget {
  const PulseHighlight({super.key, required this.child, this.active = true});

  final Widget child;
  final bool active;

  @override
  State<PulseHighlight> createState() => _PulseHighlightState();
}

class _PulseHighlightState extends State<PulseHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.saffron.withValues(alpha: 0.25 + 0.5 * _controller.value),
                blurRadius: 4 + 8 * _controller.value,
                spreadRadius: 1 + 2 * _controller.value,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
