import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The arched top of a Najdi doorway, used to frame plant photos instead of
/// a plain rectangle: a rounded dome over straight sides, with softly
/// rounded bottom corners.
class ArchClipper extends CustomClipper<Path> {
  const ArchClipper({this.bottomRadius = MashtalSpace.radius});
  final double bottomRadius;

  static Path archPath(Size size, double bottomRadius) {
    final w = size.width, h = size.height;
    final dome = (w * 0.42).clamp(0.0, h / 2);
    final r = bottomRadius.clamp(0.0, w / 2);
    return Path()
      ..moveTo(0, dome)
      ..arcToPoint(Offset(w, dome), radius: Radius.elliptical(w / 2, dome))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..close();
  }

  @override
  Path getClip(Size size) => archPath(size, bottomRadius);

  @override
  bool shouldReclip(ArchClipper old) => old.bottomRadius != bottomRadius;
}

/// Clips [child] to the arch.
class Arch extends StatelessWidget {
  const Arch({super.key, required this.child, this.bottomRadius = MashtalSpace.radius});
  final Widget child;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) => ClipPath(clipper: ArchClipper(bottomRadius: bottomRadius), child: child);
}
