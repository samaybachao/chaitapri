import 'dart:ui' show Offset, Rect;

/// Size of the drawing space. The painter scales it to the widget.
const double kSceneWidth = 360;
const double kSceneHeight = 270;

/// Where the waiting VIP customer stands (and where a tap counts as "VIP tapped").
const Offset kVipPosition = Offset(40, 246);
const Rect kVipHitRect = Rect.fromLTRB(4, 196, 78, 270);

/// What the picture shows; built from the game state by the scene widget.
class SceneParams {
  const SceneParams({
    required this.seats,
    required this.helper,
    required this.radioLevel,
    required this.boardLevel,
    required this.boost,
    required this.vip,
  });

  /// Customers sitting at the stall.
  final int seats;

  /// A helper (bought or from an ad) is working.
  final bool helper;
  final int radioLevel;
  final int boardLevel;

  /// The 2x boost is running: the stall glows.
  final bool boost;

  /// A VIP customer is waiting.
  final bool vip;
}

/// A "+12" that floats up from the place that was tapped.
class FloatingText {
  FloatingText({required this.position, required this.text, required this.born});

  /// Start point in drawing coordinates.
  final Offset position;
  final String text;

  /// Scene time (seconds) when it appeared.
  final double born;

  static const double lifetime = 0.9;

  bool isAlive(double now) => now - born < lifetime;
}
