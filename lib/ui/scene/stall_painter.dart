import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:chai_tapri/ui/scene/scene_model.dart';
import 'package:chai_tapri/ui/theme.dart';

/// Draws the chai stall. Everything is simple shapes, so the game has no image files.
class StallPainter extends CustomPainter {
  StallPainter({
    required this.time,
    required this.params,
    required this.floats,
    required this.lastTapTime,
  }) : super(repaint: time);

  /// Seconds since the scene started; the painter repaints whenever it changes.
  final ValueListenable<double> time;
  final SceneParams params;
  final List<FloatingText> floats;

  /// Scene time of the last tap (the kettle pops for a moment after it).
  final ValueListenable<double> lastTapTime;

  static final TextPainter _signText = _makeText(
    'CHAI',
    const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: 4,
    ),
  );
  static final TextPainter _vipText = _makeText(
    'VIP',
    const TextStyle(color: AppColors.brown, fontSize: 11, fontWeight: FontWeight.w900),
  );
  static final Map<String, TextPainter> _floatCache = <String, TextPainter>{};

  static TextPainter _makeText(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  static TextPainter _floatText(String text) {
    final TextPainter? cached = _floatCache[text];
    if (cached != null) {
      return cached;
    }
    if (_floatCache.length > 60) {
      _floatCache.clear();
    }
    final TextPainter made = _makeText(
      text,
      const TextStyle(
        color: Color(0xFFFFF3B0),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        shadows: <Shadow>[Shadow(color: Color(0xFF5A3410), blurRadius: 3, offset: Offset(1, 1))],
      ),
    );
    _floatCache[text] = made;
    return made;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = time.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / kSceneWidth, size.height / kSceneHeight);

    _sky(canvas);
    _signboard(canvas, t);
    _stallBack(canvas, t);
    _people(canvas, t);
    _counter(canvas, t);
    _awning(canvas);
    _seats(canvas, t);
    if (params.vip) {
      _vip(canvas, t);
    }
    _floats(canvas, t);
    canvas.restore();
  }

  void _sky(Canvas canvas) {
    const Rect sky = Rect.fromLTWH(0, 0, kSceneWidth, 200);
    final Paint skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        sky.topCenter,
        sky.bottomCenter,
        <Color>[
          params.boost ? const Color(0xFFFFD27A) : const Color(0xFFFFE2A8),
          const Color(0xFFFFF4E0),
        ],
      );
    canvas.drawRect(sky, skyPaint);
    // Far houses.
    final Paint house = Paint()..color = AppColors.creamDark;
    canvas.drawRect(const Rect.fromLTWH(0, 120, 70, 80), house);
    canvas.drawRect(const Rect.fromLTWH(300, 100, 60, 100), house);
    canvas.drawRect(const Rect.fromLTWH(12, 108, 30, 14), house);
    final Paint window = Paint()..color = const Color(0xFFE2C58C);
    canvas.drawRect(const Rect.fromLTWH(14, 136, 14, 18), window);
    canvas.drawRect(const Rect.fromLTWH(40, 136, 14, 18), window);
    canvas.drawRect(const Rect.fromLTWH(312, 118, 14, 18), window);
    canvas.drawRect(const Rect.fromLTWH(334, 118, 14, 18), window);
    // Road.
    canvas.drawRect(const Rect.fromLTWH(0, 200, kSceneWidth, 70), Paint()..color = const Color(0xFFE9D3A6));
    canvas.drawRect(const Rect.fromLTWH(0, 200, kSceneWidth, 4), Paint()..color = const Color(0xFFD2B887));
  }

  void _signboard(Canvas canvas, double t) {
    const Rect board = Rect.fromLTWH(105, 8, 150, 36);
    final RRect shape = RRect.fromRectAndRadius(board, const Radius.circular(8));
    canvas.drawRRect(shape, Paint()..color = AppColors.leafDark);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _signText.paint(
      canvas,
      Offset(board.center.dx - _signText.width / 2, board.center.dy - _signText.height / 2),
    );
    // Bulbs: more lamps for a better signboard.
    final int bulbs = math.min(12, 2 + params.boardLevel ~/ 2);
    for (int i = 0; i < bulbs; i++) {
      final double x = board.left + 6 + (board.width - 12) * (bulbs == 1 ? 0.5 : i / (bulbs - 1));
      final bool top = i.isEven;
      final double y = top ? board.top - 4 : board.bottom + 4;
      final double blink = 0.55 + 0.45 * math.sin(t * 4 + i * 1.3);
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()..color = AppColors.gold.withValues(alpha: blink.clamp(0.2, 1.0)),
      );
    }
    // Posts holding the board.
    final Paint post = Paint()..color = AppColors.chai;
    canvas.drawRect(const Rect.fromLTWH(140, 44, 4, 26), post);
    canvas.drawRect(const Rect.fromLTWH(216, 44, 4, 26), post);
  }

  void _stallBack(Canvas canvas, double t) {
    // Back wall of the stall.
    canvas.drawRect(const Rect.fromLTWH(70, 88, 220, 112), Paint()..color = const Color(0xFFF7DDAA));
    // Shelf with jars.
    canvas.drawRect(const Rect.fromLTWH(78, 112, 70, 4), Paint()..color = AppColors.chai);
    final List<Color> jarColors = <Color>[AppColors.chili, AppColors.leaf, AppColors.saffron];
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(84.0 + i * 20, 98, 14, 14), const Radius.circular(3)),
        Paint()..color = jarColors[i],
      );
    }
    // Poles.
    final Paint pole = Paint()..color = AppColors.chai;
    canvas.drawRect(const Rect.fromLTWH(66, 84, 6, 116), pole);
    canvas.drawRect(const Rect.fromLTWH(288, 84, 6, 116), pole);
    if (params.boost) {
      canvas.drawRect(
        const Rect.fromLTWH(70, 88, 220, 112),
        Paint()..color = AppColors.gold.withValues(alpha: 0.10 + 0.05 * math.sin(t * 5)),
      );
    }
  }

  void _people(Canvas canvas, double t) {
    // Owner.
    _person(canvas, const Offset(190, 160), AppColors.saffron, const Color(0xFFE0A877), 1.1, t, 0.0, cap: Colors.white);
    if (params.helper) {
      _person(canvas, const Offset(238, 160), AppColors.leaf, const Color(0xFFD9A06A), 1.0, t, 1.7, cap: AppColors.chili);
    }
  }

  void _counter(Canvas canvas, double t) {
    final double since = t - lastTapTime.value;
    final double pulse = since >= 0 && since < 0.2 ? 1.0 + 0.12 * (1 - since / 0.2) : 1.0;

    // Counter body.
    final RRect body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(66, 160, 228, 40),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.chai);
    canvas.drawRect(const Rect.fromLTWH(62, 156, 236, 8), Paint()..color = AppColors.chaiLight);
    canvas.drawRect(const Rect.fromLTWH(74, 172, 212, 3), Paint()..color = AppColors.brown.withValues(alpha: 0.35));

    // Chulha with flames and kettle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(84, 140, 52, 18), const Radius.circular(3)),
      Paint()..color = const Color(0xFF4A3A30),
    );
    for (int i = 0; i < 4; i++) {
      final double flick = 0.7 + 0.3 * math.sin(t * 13 + i * 2.1);
      final double x = 94.0 + i * 11;
      final Path flame = Path()
        ..moveTo(x - 4, 142)
        ..quadraticBezierTo(x, 142 - 14 * flick, x + 4, 142)
        ..close();
      canvas.drawPath(flame, Paint()..color = i.isEven ? AppColors.saffron : AppColors.chili);
    }

    canvas.save();
    canvas.translate(110, 130);
    canvas.scale(pulse, pulse);
    _kettle(canvas);
    canvas.restore();
    _steam(canvas, t);

    // Cups.
    for (int i = 0; i < 3; i++) {
      _cup(canvas, Offset(150.0 + i * 14, 156));
    }

    // Radio with music notes.
    final RRect radio = RRect.fromRectAndRadius(
      const Rect.fromLTWH(262, 142, 24, 15),
      const Radius.circular(3),
    );
    canvas.drawRRect(radio, Paint()..color = const Color(0xFF3A3A3A));
    canvas.drawCircle(const Offset(270, 150), 4, Paint()..color = const Color(0xFF8F8F8F));
    canvas.drawRect(const Rect.fromLTWH(278, 146, 5, 2), Paint()..color = AppColors.saffron);
    canvas.drawLine(
      const Offset(284, 142),
      const Offset(294, 128),
      Paint()
        ..color = const Color(0xFF3A3A3A)
        ..strokeWidth = 1.5,
    );
    if (params.radioLevel > 0) {
      for (int i = 0; i < 2; i++) {
        final double phase = (t * 0.5 + i * 0.5) % 1.0;
        final Offset p = Offset(272 + 10 * math.sin(phase * 6 + i), 136 - 30 * phase);
        _note(canvas, p, 1.0 - phase);
      }
    }
  }

  void _kettle(Canvas canvas) {
    final Paint steel = Paint()..color = const Color(0xFFB9BEC4);
    final Paint dark = Paint()
      ..color = const Color(0xFF6C7278)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -22, 32, 24), const Radius.circular(8)),
      steel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -27, 24, 7), const Radius.circular(3)),
      Paint()..color = const Color(0xFFA2A8AE),
    );
    // Spout and handle.
    final Path spout = Path()
      ..moveTo(15, -12)
      ..quadraticBezierTo(24, -16, 26, -24);
    canvas.drawPath(spout, dark);
    final Path handle = Path()
      ..moveTo(-15, -16)
      ..quadraticBezierTo(-28, -14, -16, -4);
    canvas.drawPath(handle, dark);
    // Shine.
    canvas.drawRect(
      const Rect.fromLTWH(-10, -18, 3, 14),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  void _steam(Canvas canvas, double t) {
    for (int i = 0; i < 3; i++) {
      final double phase = (t * 0.55 + i / 3.0) % 1.0;
      final Offset base = Offset(112 + i * 5.0 + 6 * math.sin(phase * 5 + i), 100 - 34 * phase);
      canvas.drawCircle(
        base,
        3 + 6 * phase,
        Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - phase)),
      );
    }
  }

  void _cup(Canvas canvas, Offset bottomCenter) {
    final Path cup = Path()
      ..moveTo(bottomCenter.dx - 5, bottomCenter.dy - 9)
      ..lineTo(bottomCenter.dx + 5, bottomCenter.dy - 9)
      ..lineTo(bottomCenter.dx + 3.5, bottomCenter.dy)
      ..lineTo(bottomCenter.dx - 3.5, bottomCenter.dy)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0xFFD99A5B));
    canvas.drawRect(
      Rect.fromLTWH(bottomCenter.dx - 5, bottomCenter.dy - 9, 10, 2.5),
      Paint()..color = const Color(0xFF8B4A1A),
    );
  }

  void _note(Canvas canvas, Offset p, double alpha) {
    final Paint paint = Paint()
      ..color = AppColors.chai.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(p, 2.6, Paint()..color = paint.color);
    canvas.drawLine(p + const Offset(2.4, 0), p + const Offset(2.4, -9), paint);
    canvas.drawLine(p + const Offset(2.4, -9), p + const Offset(6, -7), paint);
  }

  void _awning(Canvas canvas) {
    const double left = 52;
    const double right = 308;
    const double top = 70;
    const double bottom = 92;
    const int stripes = 8;
    const double stripeWidth = (right - left) / stripes;
    for (int i = 0; i < stripes; i++) {
      final Color color = i.isEven ? AppColors.chili : const Color(0xFFFFF1D6);
      final double x = left + i * stripeWidth;
      final Path stripe = Path()
        ..moveTo(x, top)
        ..lineTo(x + stripeWidth, top)
        ..lineTo(x + stripeWidth, bottom)
        ..arcToPoint(
          Offset(x, bottom),
          radius: const Radius.circular(stripeWidth / 2),
          clockwise: true,
        )
        ..close();
      canvas.drawPath(stripe, Paint()..color = color);
    }
    canvas.drawRect(
      const Rect.fromLTWH(left, top - 4, right - left, 6),
      Paint()..color = AppColors.brown.withValues(alpha: 0.35),
    );
  }

  void _seats(Canvas canvas, double t) {
    final int count = params.seats.clamp(0, 12);
    for (int i = 0; i < count; i++) {
      final int row = i ~/ 6;
      final int col = i % 6;
      final double x = 110.0 + col * 40 + (row == 1 ? 18 : 0);
      final double y = row == 0 ? 232.0 : 262.0;
      // Stool.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 11, y - 8, 22, 5), const Radius.circular(2)),
        Paint()..color = AppColors.chai,
      );
      canvas.drawRect(Rect.fromLTWH(x - 8, y - 3, 3, 9), Paint()..color = AppColors.brown);
      canvas.drawRect(Rect.fromLTWH(x + 5, y - 3, 3, 9), Paint()..color = AppColors.brown);
      // Customer.
      const List<Color> shirts = <Color>[
        Color(0xFF4F7CAC),
        Color(0xFFB5527A),
        Color(0xFF6A994E),
        Color(0xFF8E6BBF),
        Color(0xFFD08C3F),
        Color(0xFF3F8F8B),
      ];
      _person(canvas, Offset(x, y - 8), shirts[(i * 5 + row) % shirts.length], const Color(0xFFD9A06A), 0.8, t, i * 0.9, sitting: true);
      // Tea glass in hand.
      _cup(canvas, Offset(x + 10, y - 12));
    }
  }

  void _vip(Canvas canvas, double t) {
    final double bob = 2 * math.sin(t * 5);
    final Offset p = kVipPosition;
    canvas.drawCircle(
      p + Offset(0, -26 + bob),
      30 + 3 * math.sin(t * 6),
      Paint()..color = AppColors.gold.withValues(alpha: 0.25),
    );
    _person(canvas, p, const Color(0xFF2E3A59), const Color(0xFFD9A06A), 1.15, t, 0.5, cap: AppColors.gold);
    // "VIP" tag above the head.
    final Rect tag = Rect.fromCenter(center: p + Offset(0, -58 + bob), width: 30, height: 15);
    canvas.drawRRect(RRect.fromRectAndRadius(tag, const Radius.circular(6)), Paint()..color = AppColors.gold);
    _vipText.paint(canvas, Offset(tag.center.dx - _vipText.width / 2, tag.center.dy - _vipText.height / 2));
  }

  /// A person standing (or sitting) with the feet at [feet].
  void _person(
    Canvas canvas,
    Offset feet,
    Color shirt,
    Color skin,
    double scale,
    double t,
    double phase, {
    Color? cap,
    bool sitting = false,
  }) {
    final double bob = 1.2 * math.sin(t * 2.4 + phase);
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(scale, scale);
    final double bodyHeight = sitting ? 16 : 26;
    final double top = -bodyHeight + bob * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-8, top, 16, bodyHeight), const Radius.circular(6)),
      Paint()..color = shirt,
    );
    if (!sitting) {
      canvas.drawRect(const Rect.fromLTWH(-6, -2, 5, 2), Paint()..color = AppColors.brown);
      canvas.drawRect(const Rect.fromLTWH(1, -2, 5, 2), Paint()..color = AppColors.brown);
    }
    final Offset head = Offset(0, top - 7 + bob * 0.5);
    canvas.drawCircle(head, 7.5, Paint()..color = skin);
    if (cap != null) {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: 8),
        math.pi,
        math.pi,
        true,
        Paint()..color = cap,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: 7.8),
        math.pi * 1.05,
        math.pi * 0.9,
        true,
        Paint()..color = const Color(0xFF2B1A0E),
      );
    }
    final Paint eye = Paint()..color = AppColors.ink;
    canvas.drawCircle(head + const Offset(-2.6, 0.5), 0.9, eye);
    canvas.drawCircle(head + const Offset(2.6, 0.5), 0.9, eye);
    canvas.restore();
  }

  void _floats(Canvas canvas, double t) {
    for (final FloatingText f in floats) {
      final double age = t - f.born;
      if (age < 0 || age >= FloatingText.lifetime) {
        continue;
      }
      final double k = age / FloatingText.lifetime;
      final TextPainter painter = _floatText(f.text);
      final Offset at = f.position + Offset(-painter.width / 2, -22 - 46 * k - painter.height / 2);
      final Rect bounds = Rect.fromLTWH(at.dx - 4, at.dy - 4, painter.width + 8, painter.height + 8);
      canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, (1 - k * k).clamp(0.0, 1.0)));
      painter.paint(canvas, at);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StallPainter oldDelegate) {
    return oldDelegate.params != params ||
        oldDelegate.floats != floats ||
        oldDelegate.time != time ||
        oldDelegate.lastTapTime != lastTapTime;
  }
}
