import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Mashtal's small line drawings: one stroke colour with round ends, a soft
/// mint fill here and there, drawn on a 100 × 100 grid and scaled. They take
/// the place of stock icons where a picture explains more (the questions,
/// where a plant lives, empty screens). Plain line art on purpose: no
/// gradients, no sparkles.
enum Art {
  smallPot,
  bigPot,
  ground,
  indoor,
  balcony,
  wateringCan,
  suitcase,
  helper,
  sprout,
  savedLeaf,
  basket,
  bell,
  sunLots,
  sunSome,
  sunLittle,
  morning,
  afternoon,
  windowSun,
  windowBright,
  windowFar,
}

class GardenArt extends StatelessWidget {
  const GardenArt(this.art, {super.key, this.size = 64, this.color = MashtalColors.forest, this.fill = MashtalColors.mint, this.label});

  final Art art;
  final double size;

  /// The line colour.
  final Color color;

  /// The soft fill behind parts of the drawing.
  final Color fill;

  /// Read out by screen readers when the drawing carries meaning.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final picture = SizedBox.square(dimension: size, child: CustomPaint(painter: _ArtPainter(art, color, fill)));
    return label == null ? ExcludeSemantics(child: picture) : Semantics(label: label, image: true, child: picture);
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.color, this.fill);
  final Art art;
  final Color color;
  final Color fill;

  late Paint _line;
  late Paint _fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.scale(s);
    _line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _fill = Paint()..color = fill;
    switch (art) {
      case Art.smallPot:
        _plant(canvas, const Offset(50, 64), height: 22, leaves: 3);
        _pot(canvas, 50, 64, 30, 26);
      case Art.bigPot:
        _plant(canvas, const Offset(50, 52), height: 34, leaves: 4);
        _pot(canvas, 50, 52, 50, 42);
      case Art.ground:
        _tree(canvas, const Offset(50, 84));
        _groundLine(canvas, 86);
      case Art.indoor:
        _archWindow(canvas, const Rect.fromLTRB(22, 8, 78, 70));
        _plant(canvas, const Offset(50, 74), height: 16, leaves: 3);
        _pot(canvas, 50, 74, 24, 18);
        canvas.drawLine(const Offset(14, 92), const Offset(86, 92), _line);
      case Art.balcony:
        _plant(canvas, const Offset(36, 52), height: 22, leaves: 4);
        _pot(canvas, 36, 52, 26, 22);
        canvas.drawLine(const Offset(10, 74), const Offset(90, 74), _line);
        canvas.drawLine(const Offset(10, 92), const Offset(90, 92), _line);
        for (var x = 18.0; x <= 82; x += 16) {
          canvas.drawLine(Offset(x, 74), Offset(x, 92), _line);
        }
        _sun(canvas, const Offset(76, 26), 9, rays: 6, rayLength: 6);
      case Art.wateringCan:
        _wateringCan(canvas);
      case Art.suitcase:
        _suitcase(canvas);
      case Art.helper:
        _wateringCan(canvas, scale: 0.8, offset: const Offset(-6, 10));
        _plant(canvas, const Offset(80, 80), height: 14, leaves: 2);
        _pot(canvas, 80, 80, 18, 14);
      case Art.sprout:
        canvas.drawLine(const Offset(50, 58), const Offset(50, 38), _line);
        _leaf(canvas, const Offset(50, 42), -math.pi / 2 - 0.8, 20);
        _leaf(canvas, const Offset(50, 42), -math.pi / 2 + 0.8, 20);
        _pot(canvas, 50, 56, 46, 36);
      case Art.savedLeaf:
        final heart = Path()
          ..moveTo(50, 84)
          ..cubicTo(14, 60, 14, 22, 34, 20)
          ..cubicTo(44, 19, 49, 27, 50, 34)
          ..cubicTo(51, 27, 56, 19, 66, 20)
          ..cubicTo(86, 22, 86, 60, 50, 84)
          ..close();
        canvas.drawPath(heart, _fill);
        canvas.drawPath(heart, _line);
        canvas.drawLine(const Offset(50, 84), const Offset(50, 40), _line);
        for (final y in [52.0, 64.0]) {
          canvas.drawLine(Offset(50, y + 6), Offset(36, y - 4), _line);
          canvas.drawLine(Offset(50, y + 6), Offset(64, y - 4), _line);
        }
      case Art.basket:
        _leaf(canvas, const Offset(40, 46), -math.pi / 2 - 0.5, 24);
        _leaf(canvas, const Offset(56, 46), -math.pi / 2 + 0.3, 28);
        _leaf(canvas, const Offset(48, 46), -math.pi / 2 - 0.05, 20);
        final b = Path()
          ..moveTo(16, 46)
          ..lineTo(84, 46)
          ..lineTo(76, 88)
          ..lineTo(24, 88)
          ..close();
        canvas.drawPath(b, _fill);
        canvas.drawPath(b, _line);
        canvas.drawLine(const Offset(20, 66), const Offset(80, 66), _line);
      case Art.bell:
        _plant(canvas, const Offset(30, 76), height: 14, leaves: 2);
        _pot(canvas, 30, 76, 20, 14);
        final bell = Path()
          ..moveTo(44, 70)
          ..quadraticBezierTo(50, 66, 52, 50)
          ..quadraticBezierTo(54, 28, 66, 26)
          ..quadraticBezierTo(78, 28, 80, 50)
          ..quadraticBezierTo(82, 66, 88, 70)
          ..close();
        canvas.drawPath(bell, _fill);
        canvas.drawPath(bell, _line);
        canvas.drawCircle(const Offset(66, 76), 4, _line);
        canvas.drawLine(const Offset(66, 26), const Offset(66, 20), _line);
      case Art.sunLots:
        _sun(canvas, const Offset(50, 40), 16, rays: 10, rayLength: 12);
        _groundLine(canvas, 86);
      case Art.sunSome:
        _sun(canvas, const Offset(64, 36), 13, rays: 8, rayLength: 8);
        _najdiWall(canvas, 16, 58, 60, 88);
      case Art.sunLittle:
        _najdiWall(canvas, 10, 30, 64, 88);
        _plant(canvas, const Offset(80, 74), height: 16, leaves: 3);
        _pot(canvas, 80, 74, 20, 14);
      case Art.morning:
        canvas.save();
        canvas.clipRect(const Rect.fromLTRB(0, 0, 100, 70));
        _sun(canvas, const Offset(50, 70), 18, rays: 9, rayLength: 10);
        canvas.restore();
        canvas.drawLine(const Offset(8, 70), const Offset(92, 70), _line);
        canvas.drawLine(const Offset(30, 84), const Offset(70, 84), _line);
      case Art.afternoon:
        _sun(canvas, const Offset(50, 34), 15, rays: 10, rayLength: 10);
        for (final x in [30.0, 50.0, 70.0]) {
          final heat = Path()..moveTo(x, 64);
          for (var i = 0; i < 3; i++) {
            heat.quadraticBezierTo(x + (i.isEven ? 5 : -5), 68 + i * 8, x, 72 + i * 8);
          }
          canvas.drawPath(heat, _line);
        }
      case Art.windowSun:
        _archWindow(canvas, const Rect.fromLTRB(14, 10, 62, 74));
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(Offset(44 + i * 8.0, 50 + i * 4.0), Offset(66 + i * 8.0, 82), _line);
        }
        _plant(canvas, const Offset(78, 70), height: 12, leaves: 2);
        _pot(canvas, 78, 70, 18, 14);
      case Art.windowBright:
        _archWindow(canvas, const Rect.fromLTRB(14, 10, 62, 74));
        _plant(canvas, const Offset(78, 70), height: 12, leaves: 2);
        _pot(canvas, 78, 70, 18, 14);
      case Art.windowFar:
        _archWindow(canvas, const Rect.fromLTRB(8, 14, 34, 50));
        _plant(canvas, const Offset(70, 66), height: 14, leaves: 3);
        _pot(canvas, 70, 66, 22, 18);
        canvas.drawLine(const Offset(8, 86), const Offset(92, 86), _line);
    }
    canvas.restore();
  }

  /// A pot whose rim is centred at ([cx], [top]): a rim band, then a body
  /// that narrows to the base.
  void _pot(Canvas canvas, double cx, double top, double w, double h) {
    const rim = 7.0;
    final body = Path()
      ..moveTo(cx - w * 0.44, top + rim)
      ..lineTo(cx + w * 0.44, top + rim)
      ..lineTo(cx + w * 0.33, top + h)
      ..lineTo(cx - w * 0.33, top + h)
      ..close();
    canvas.drawPath(body, _fill);
    canvas.drawPath(body, _line);
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(cx - w / 2, top, cx + w / 2, top + rim), const Radius.circular(2.5));
    canvas.drawRRect(r, Paint()..color = MashtalColors.surface);
    canvas.drawRRect(r, _line);
  }

  /// A plant growing up from [base]: a stem and leaves in pairs.
  void _plant(Canvas canvas, Offset base, {required double height, required int leaves}) {
    final top = base.translate(0, -height);
    canvas.drawLine(base, top, _line);
    for (var i = 0; i < leaves; i++) {
      final t = (i + 1) / (leaves + 1);
      final at = Offset(base.dx, base.dy - height * t);
      final side = i.isEven ? -1 : 1;
      _leaf(canvas, at, -math.pi / 2 + side * 0.9, height * 0.45 + 4);
    }
    _leaf(canvas, top, -math.pi / 2, height * 0.35 + 4);
  }

  /// A pointed leaf from [at], [length] long, at [angle] radians.
  void _leaf(Canvas canvas, Offset at, double angle, double length) {
    final tip = at + Offset(math.cos(angle), math.sin(angle)) * length;
    final n = Offset(-math.sin(angle), math.cos(angle)) * (length * 0.32);
    final mid = Offset.lerp(at, tip, 0.5)!;
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, at.dx, at.dy)
      ..close();
    canvas.drawPath(p, _fill);
    canvas.drawPath(p, _line);
  }

  void _tree(Canvas canvas, Offset base) {
    canvas.drawLine(base, base.translate(0, -34), _line);
    canvas.drawLine(base.translate(0, -18), base.translate(-10, -28), _line);
    // One outline around three overlapping circles, like a canopy.
    Path circle(Offset c, double r) => Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final crown = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, circle(base.translate(-14, -46), 14), circle(base.translate(12, -48), 15)),
      circle(base.translate(0, -62), 16),
    );
    canvas.drawPath(crown, _fill);
    canvas.drawPath(crown, _line);
  }

  void _groundLine(Canvas canvas, double y) {
    final p = Path()..moveTo(8, y);
    p.quadraticBezierTo(30, y - 4, 50, y);
    p.quadraticBezierTo(70, y + 4, 92, y);
    canvas.drawPath(p, _line);
  }

  void _sun(Canvas canvas, Offset c, double r, {required int rays, required double rayLength}) {
    canvas.drawCircle(c, r, Paint()..color = MashtalColors.sand);
    canvas.drawCircle(c, r, _line);
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 5), c + d * (r + 5 + rayLength), _line);
    }
  }

  /// An arched window, the shape of a Najdi doorway.
  void _archWindow(Canvas canvas, Rect r) {
    final w = r.width;
    final path = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + w / 2)
      ..arcToPoint(Offset(r.right, r.top + w / 2), radius: Radius.circular(w / 2))
      ..lineTo(r.right, r.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = MashtalColors.waterSoft);
    canvas.drawPath(path, _line);
    canvas.drawLine(Offset(r.center.dx, r.top + 4), Offset(r.center.dx, r.bottom), _line);
    canvas.drawLine(Offset(r.left, r.top + w / 2 + 6), Offset(r.right, r.top + w / 2 + 6), _line);
  }

  /// A mud wall with the triangle crenellations of old Riyadh houses.
  void _najdiWall(Canvas canvas, double left, double top, double right, double bottom) {
    final p = Path()..moveTo(left, bottom);
    p.lineTo(left, top + 8);
    final teeth = ((right - left) / 12).floor();
    final step = (right - left) / teeth;
    for (var i = 0; i < teeth; i++) {
      p.lineTo(left + step * i + step / 2, top);
      p.lineTo(left + step * (i + 1), top + 8);
    }
    p
      ..lineTo(right, bottom)
      ..close();
    canvas.drawPath(p, Paint()..color = MashtalColors.sand);
    canvas.drawPath(p, _line);
    // A small arched door.
    final dw = (right - left) * 0.28;
    final dx = (left + right) / 2 - dw / 2;
    final door = Path()
      ..moveTo(dx, bottom)
      ..lineTo(dx, bottom - 14)
      ..arcToPoint(Offset(dx + dw, bottom - 14), radius: Radius.circular(dw / 2))
      ..lineTo(dx + dw, bottom);
    canvas.drawPath(door, _line);
  }

  void _wateringCan(Canvas canvas, {double scale = 1, Offset offset = Offset.zero}) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.translate(50 * (1 - scale), 50 * (1 - scale));
    canvas.scale(scale);
    final body = RRect.fromRectAndRadius(const Rect.fromLTRB(26, 42, 70, 82), const Radius.circular(8));
    canvas.drawRRect(body, _fill);
    canvas.drawRRect(body, _line);
    canvas.drawArc(const Rect.fromLTRB(34, 24, 64, 56), math.pi, math.pi, false, _line);
    final spout = Path()
      ..moveTo(28, 56)
      ..lineTo(12, 36);
    canvas.drawPath(spout, _line);
    canvas.drawLine(const Offset(6, 34), const Offset(16, 30), _line);
    for (final d in [const Offset(6, 48), const Offset(12, 58), const Offset(4, 64)]) {
      _drop(canvas, d, 3.2);
    }
    canvas.restore();
  }

  void _drop(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r * 1.8)
      ..quadraticBezierTo(c.dx + r * 1.2, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 1.2, c.dy, c.dx, c.dy - r * 1.8)
      ..close();
    canvas.drawPath(p, Paint()..color = MashtalColors.water);
  }

  void _suitcase(Canvas canvas) {
    final body = RRect.fromRectAndRadius(const Rect.fromLTRB(18, 40, 82, 86), const Radius.circular(8));
    canvas.drawRRect(body, _fill);
    canvas.drawRRect(body, _line);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(38, 30, 62, 40), const Radius.circular(4)), _line);
    canvas.drawLine(const Offset(36, 40), const Offset(36, 86), _line);
    canvas.drawLine(const Offset(64, 40), const Offset(64, 86), _line);
    canvas.drawCircle(const Offset(28, 90), 3, _line);
    canvas.drawCircle(const Offset(72, 90), 3, _line);
    _leaf(canvas, const Offset(50, 30), -math.pi / 2 - 0.8, 14);
    _leaf(canvas, const Offset(50, 30), -math.pi / 2 + 0.8, 14);
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art || old.color != color || old.fill != fill;
}
