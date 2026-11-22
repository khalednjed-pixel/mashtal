import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../logic/directions.dart';
import '../../models/models.dart';
import '../theme.dart';

/// Opens a link outside the app (the map or phone app). Replaced in tests.
Future<bool> Function(Uri) openExternal = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// The torn-off half of an accepted reservation (US-18): where and when to
/// collect, how much of the 48-hour hold is left, and directions.
class PickupPass extends StatelessWidget {
  const PickupPass({super.key, required this.reservation, required this.nursery, required this.now});

  final Reservation reservation;
  final Nursery nursery;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    final left = reservation.expiresAt!.difference(now);
    final share = (left.inMinutes / Reservation.holdFor.inMinutes).clamp(0.0, 1.0);
    final hours = (left.inMinutes / 60).ceil().clamp(0, Reservation.holdFor.inHours);
    return Column(
      key: Key('pickupPass-${reservation.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Perforation(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How much of the hold is left, as a ring that empties.
            Semantics(
              label: context.tr('hoursLeft').replaceAll('{h}', '$hours'),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: share,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: MashtalColors.sprout,
                      backgroundColor: MashtalColors.ground,
                    ),
                    Center(
                      child: ExcludeSemantics(
                        child: Text('$hours', style: text.titleMedium?.copyWith(color: MashtalColors.forest)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MashtalSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('pickupAt'), style: text.labelSmall),
                  Text(nursery.name(lang), style: text.titleMedium),
                  _Fact(icon: Icons.place_outlined, text: '${nursery.district} · ${context.trCity(nursery.city)}', key: Key('pickupAddress-${reservation.id}')),
                  // Hours read left to right in both languages.
                  _Fact(icon: Icons.schedule, text: '${context.tr('hours')}: \u2066${nursery.hours}\u2069', key: Key('pickupHours-${reservation.id}')),
                  Text(context.tr('hoursLeft').replaceAll('{h}', '$hours'), style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: MashtalSpace.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: Key('directions-${reservation.id}'),
                icon: const Icon(Icons.directions_outlined),
                label: Text(context.tr('directions')),
                onPressed: () => openExternal(directionsTo(nursery)),
              ),
            ),
            const SizedBox(width: MashtalSpace.sm),
            IconButton.outlined(
              key: Key('call-${reservation.id}'),
              tooltip: context.tr('callNursery'),
              style: IconButton.styleFrom(side: const BorderSide(color: MashtalColors.leaf)),
              icon: const Icon(Icons.call_outlined),
              onPressed: () => openExternal(Uri(scheme: 'tel', path: nursery.phone)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(icon, size: 16, color: MashtalColors.leaf),
            const SizedBox(width: MashtalSpace.xs),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

/// A ticket's tear line: a dashed rule with a notch cut into each edge of the
/// card. The card clips the notches, so they read as bites out of it.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DashLine())),
            for (final side in [-1.0, 1.0])
              Positioned(
                left: side < 0 ? -MashtalSpace.md - 10 : null,
                right: side > 0 ? -MashtalSpace.md - 10 : null,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: MashtalColors.page, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      );
}

class _DashLine extends CustomPainter {
  const _DashLine();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MashtalColors.line
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    for (var x = 4.0; x < size.width - 4; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashLine oldDelegate) => false;
}
