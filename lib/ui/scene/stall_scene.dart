import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/core/formatting.dart';
import 'package:chai_tapri/state/game_controller.dart';
import 'package:chai_tapri/ui/scene/scene_model.dart';
import 'package:chai_tapri/ui/scene/stall_painter.dart';

/// The picture of the stall. Tapping it brews chai; tapping the VIP customer opens
/// the tip dialog.
class StallScene extends StatefulWidget {
  const StallScene({super.key, required this.onVipTap});

  final VoidCallback onVipTap;

  @override
  State<StallScene> createState() => _StallSceneState();
}

class _StallSceneState extends State<StallScene> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final ValueNotifier<double> _lastTap = ValueNotifier<double>(-10);
  final List<FloatingText> _floats = <FloatingText>[];
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1000000.0;
    _floats.removeWhere((FloatingText f) => !f.isAlive(now));
    _time.value = now;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _lastTap.dispose();
    super.dispose();
  }

  void _handlePointer(GameController game, Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final Offset point = Offset(
      local.dx * kSceneWidth / size.width,
      local.dy * kSceneHeight / size.height,
    );
    if (game.vipWaiting && kVipHitRect.contains(point)) {
      widget.onVipTap();
      return;
    }
    _tapAt(game, point);
  }

  void _tapAt(GameController game, Offset point) {
    final double earned = game.tap();
    final double now = _time.value;
    _lastTap.value = now;
    if (_floats.length >= 10) {
      _floats.removeAt(0);
    }
    final String text = earned >= 1 ? '+${formatNumber(earned)}' : '+${formatRate(earned)}';
    _floats.add(FloatingText(position: point, text: text, born: now));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.app;
    final GameController game = services.game;
    return ListenableBuilder(
      listenable: game,
      builder: (BuildContext context, Widget? child) {
        final SceneParams params = SceneParams(
          seats: game.snapshot.seatCount,
          helper: game.engine.helperActive,
          radioLevel: game.state.levels[game.economy.radioIndex],
          boardLevel: game.state.levels[game.economy.boardIndex],
          boost: game.boostActive,
          vip: game.vipWaiting,
        );
        return AspectRatio(
          aspectRatio: kSceneWidth / kSceneHeight,
          child: Semantics(
            label: context.t('sem_scene'),
            button: true,
            onTap: () => _tapAt(game, const Offset(110, 120)),
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = constraints.biggest;
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (PointerDownEvent event) {
                      _handlePointer(game, event.localPosition, size);
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: StallPainter(
                          time: _time,
                          params: params,
                          floats: _floats,
                          lastTapTime: _lastTap,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
