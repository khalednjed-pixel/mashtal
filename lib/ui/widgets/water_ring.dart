import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../logic/care_plan.dart';
import '../theme.dart';

/// The plant page's one big action: a round "soil" that shows how much water
/// is likely left (the outer ring drains over the days) and fills with water
/// while it is pressed and held. Holding, not tapping, so a plant is not
/// marked watered by an accidental touch. Screen readers get a plain tap.
class WaterRing extends StatefulWidget {
  const WaterRing({super.key, required this.plan, required this.onWatered, this.size = 240});

  final CarePlan plan;
  final Future<void> Function() onWatered;
  final double size;

  /// How long the press has to be held.
  static const holdFor = Duration(milliseconds: 1100);

  @override
  State<WaterRing> createState() => _WaterRingState();
}

class _WaterRingState extends State<WaterRing> with TickerProviderStateMixin {
  late final _fill = AnimationController(vsync: this, duration: WaterRing.holdFor)..addStatusListener(_onStatus);

  /// Moves the water's surface while it rises.
  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _done = false;
  Offset? _down;

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_done) _complete();
  }

  Future<void> _complete() async {
    if (_done) return;
    HapticFeedback.mediumImpact();
    setState(() => _done = true);
    _fill.value = 1;
    _wave.stop();
    await widget.onWatered();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _done = false);
    _fill.animateBack(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
  }

  void _start(PointerDownEvent e) {
    if (_done) return;
    _down = e.position;
    HapticFeedback.selectionClick();
    _wave.repeat();
    _fill.forward();
  }

  void _release([PointerEvent? _]) {
    _down = null;
    if (_done) return;
    _wave.stop();
    _fill.animateBack(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = widget.plan;
    final title = _done
        ? context.tr('wateredRing')
        : plan.dueInDays < 0
        ? context.tr('checkSoilLate')
        : plan.isDue
        ? context.tr('checkSoilToday')
        : context.tr('soilMoist');
    return Semantics(
      button: true,
      label: '$title. ${context.tr('holdToWater')}',
      onTap: _complete,
      child: ExcludeSemantics(
        child: Listener(
          key: const Key('waterNow'),
          onPointerDown: _start,
          onPointerUp: _release,
          onPointerCancel: _release,
          // Scrolling the page is not a press.
          onPointerMove: (e) {
            if (_down != null && (e.position - _down!).distance > 16) _release();
          },
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_fill, _wave]),
              builder: (context, _) {
                final holding = _fill.value > 0 && !_done;
                return CustomPaint(
                  painter: _RingPainter(moisture: _done ? 1 : plan.moisture, fill: _fill.value, phase: _wave.value),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(34),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: widget.size - 68),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _done ? Icons.check_rounded : Icons.water_drop_outlined,
                                  key: ValueKey(_done),
                                  size: 40,
                                  color: _done ? MashtalColors.forest : MashtalColors.water,
                                ),
                              ),
                              const SizedBox(height: MashtalSpace.xs),
                              Text(title, textAlign: TextAlign.center, style: text.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                _done ? '' : (holding ? context.tr('keepHolding') : context.tr('holdToWater')),
                                textAlign: TextAlign.center,
                                style: text.bodySmall?.copyWith(color: plan.isDue ? MashtalColors.water : MashtalColors.forestDeep),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Outer ring: water left in the soil. Inside: a white disc that fills with
/// water from the bottom, with a gentle wave on top while it rises.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.moisture, required this.fill, required this.phase});
  final double moisture;
  final double fill;
  final double phase;

  static const stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = MashtalColors.waterSoft;
    canvas.drawCircle(c, r, track);
    if (moisture > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * moisture,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = MashtalColors.water,
      );
    }

    final inner = r - stroke - 6;
    final disc = Rect.fromCircle(center: c, radius: inner);
    // The soil itself: white when freshly watered, sandy as it dries.
    canvas.drawCircle(c, inner, Paint()..color = Color.lerp(MashtalColors.sand, MashtalColors.surface, moisture)!);
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = MashtalColors.line,
    );
    if (fill <= 0) return;
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    final top = disc.bottom - disc.height * fill;
    final amp = fill >= 1 ? 0.0 : 6.0;
    final path = Path()..moveTo(disc.left, disc.bottom);
    for (var x = disc.left; x <= disc.right; x += 4) {
      final t = (x - disc.left) / disc.width;
      path.lineTo(x, top + math.sin((t * 2 + phase * 2) * math.pi) * amp);
    }
    path
      ..lineTo(disc.right, disc.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = MashtalColors.waterLight.withValues(alpha: 0.55));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.moisture != moisture || old.fill != fill || old.phase != phase;
}
