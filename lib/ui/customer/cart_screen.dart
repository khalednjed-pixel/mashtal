import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/garden_art.dart';
import '../widgets/plant_photo.dart';

typedef _Line = ({Listing listing, int qty, Plant plant});

/// Cart as a pickup route (US-15): one numbered stop per nursery, each with
/// its plants and subtotal, joined by a dashed path because every nursery is
/// a separate pickup. Lines that are no longer available stay visible,
/// flagged, and are not reserved (AC-02). A guest's choices survive sign-in
/// (US-01 AC-02); a customer reserves it, one reservation per nursery (US-16).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;

    // Group by nursery, keeping the order the lines were added in.
    final stops = <Nursery, List<_Line>>{};
    for (final MapEntry(key: id, value: qty) in app.cart.entries) {
      final listing = market.listings.where((l) => l.id == id).firstOrNull;
      final plant = listing == null ? null : market.plantById(listing.plantId);
      final nursery = listing == null ? null : market.nurseryById(listing.nurseryId);
      if (listing == null || plant == null || nursery == null) continue;
      stops.putIfAbsent(nursery, () => []).add((listing: listing, qty: qty, plant: plant));
    }
    double sum(Iterable<_Line> lines) =>
        lines.where((l) => l.listing.isAvailable).fold(0, (s, l) => s + l.listing.price * l.qty);
    final total = sum(stops.values.expand((l) => l));
    final reservableStops = stops.values.where((lines) => lines.any((l) => l.listing.isAvailable)).length;
    // Stops where something can still be reserved; the pickup note counts these.

    if (app.cartAdjusted) {
      app.cartAdjusted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('cartAdjusted'))));
      });
    }

    Future<void> reserve() async {
      if (app.user == null) {
        context.go('/login?from=/cart');
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      final reservedText = context.trCount;
      final nothing = context.tr('reserveNothing');
      final made = await app.reserveCart();
      if (made == 0) {
        messenger.showSnackBar(SnackBar(content: Text(nothing)));
        return;
      }
      router.go('/reservations');
      messenger.showSnackBar(SnackBar(content: Text(reservedText('reservedDone', made))));
    }

    final text = Theme.of(context).textTheme;
    final several = stops.length > 1;
    final pickups = reservableStops;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('cart')), actions: const [LanguageButton()]),
      body: stops.isEmpty
          ? EmptyState(
              icon: Icons.shopping_basket_outlined,
              art: Art.basket,
              title: context.tr('cartEmpty'),
              actions: [OutlinedButton(onPressed: () => context.go('/shop'), child: Text(context.tr('buyPlants')))],
            )
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
                children: [
                  if (pickups > 1) ...[
                    _RouteNote(text: context.trCount('separatePickups', pickups)),
                    const SizedBox(height: MashtalSpace.lg),
                  ],
                  for (final (i, MapEntry(key: nursery, value: lines)) in stops.entries.indexed)
                    _PickupStop(
                      key: Key('stop-${nursery.id}'),
                      number: i + 1,
                      nursery: nursery,
                      lines: lines,
                      // With one nursery the subtotal is the total; say it once.
                      // Nothing to pay at a stop whose plants are all unavailable.
                      subtotal: several && sum(lines) > 0 ? sum(lines) : null,
                      last: i == stops.length - 1,
                    ),
                  // Total and the screen's one primary action. Kept in the list,
                  // not pinned to the bottom, so the "added" message never covers it.
                  const SizedBox(height: MashtalSpace.sm),
                  Card(
                    color: MashtalColors.ground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                    child: Padding(
                      padding: const EdgeInsets.all(MashtalSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(context.tr('total'), style: text.titleMedium),
                              const Spacer(),
                              Text(formatPrice(context, total), key: const Key('cartTotal'), style: text.titleLarge?.copyWith(color: MashtalColors.forestDeep)),
                            ],
                          ),
                          if (reservableStops > 0)
                            Text(
                              context.trCount('willSend', reservableStops),
                              style: text.bodySmall,
                            ),
                          const SizedBox(height: MashtalSpace.md),
                          FilledButton.icon(
                            key: const Key('reserve'),
                            icon: const Icon(Icons.event_available),
                            label: Text(context.tr('reserve')),
                            onPressed: reserve,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Explains that a cart spanning nurseries means one pickup per nursery.
class _RouteNote extends StatelessWidget {
  const _RouteNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('separatePickups'),
        padding: const EdgeInsets.all(MashtalSpace.md),
        decoration: BoxDecoration(color: MashtalColors.mint, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.alt_route, color: MashtalColors.forest),
            const SizedBox(width: MashtalSpace.md),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

/// One stop on the pickup route: a numbered marker on the rail, the
/// nursery, its lines and (when the cart has several stops) its subtotal.
class _PickupStop extends StatelessWidget {
  const _PickupStop({super.key, required this.number, required this.nursery, required this.lines, required this.subtotal, required this.last});

  final int number;
  final Nursery nursery;
  final List<_Line> lines;
  final double? subtotal;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail: stop marker, then a dashed path down to the next stop.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                StopMarker(number: number),
                if (!last) const Expanded(child: DashedRail()),
              ],
            ),
          ),
          const SizedBox(width: MashtalSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: MashtalSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('pickupStop').replaceAll('{n}', '$number'), style: text.labelSmall),
                  Row(
                    children: [
                      Expanded(child: Text(nursery.name(lang), style: text.titleMedium)),
                      RatingLabel(rating: nursery.rating),
                    ],
                  ),
                  Text(
                    // Hours read left to right in both languages (8:00–22:00).
                    '${nursery.district} · ${context.trCity(nursery.city)} · \u2066${nursery.hours}\u2069',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: MashtalSpace.sm),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, line) in lines.indexed) ...[
                          if (i > 0) const Divider(indent: MashtalSpace.md, endIndent: MashtalSpace.md),
                          _CartLine(line: line),
                        ],
                        if (subtotal != null)
                          Container(
                            color: MashtalColors.ground,
                            padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.sm),
                            child: Row(
                              children: [
                                Text(context.tr('subtotal'), style: text.bodyMedium),
                                const Spacer(),
                                Text(formatPrice(context, subtotal!), key: Key('subtotal-${nursery.id}'), style: text.titleMedium),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.line});
  final _Line line;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final (:listing, :qty, :plant) = line;
    final available = listing.isAvailable;
    return Padding(
      key: Key('cartLine-${listing.id}'),
      padding: const EdgeInsets.all(MashtalSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(opacity: available ? 1 : 0.45, child: PlantPhoto(plant: plant, listingPhoto: listing.photo, size: 72)),
          const SizedBox(width: MashtalSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plant.name(lang), style: text.titleMedium),
                if (available)
                  Text('${formatPrice(context, listing.price)} · ${context.tr('onlyLeft')}: ${listing.quantity}', style: text.bodySmall)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: MashtalSpace.xs),
                    child: Container(
                      key: Key('unavailable-${listing.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.sm, vertical: 2),
                      decoration: const ShapeDecoration(color: MashtalColors.errorSoft, shape: StadiumBorder()),
                      child: Text(context.tr('unavailableNow'), style: text.labelSmall?.copyWith(color: MashtalColors.error)),
                    ),
                  ),
                const SizedBox(height: MashtalSpace.xs),
                Row(
                  children: [
                    if (available)
                      // Quantity stepper in one pill.
                      DecoratedBox(
                        decoration: const ShapeDecoration(shape: StadiumBorder(), color: MashtalColors.ground),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('decrease-${listing.id}'),
                              tooltip: context.tr('decrease'),
                              icon: const Icon(Icons.remove),
                              // At 1 the minus takes the line out, so it asks first too.
                              onPressed: () async {
                                if (qty > 1 || await confirmRemoveFromCart(context, plant.name(lang))) app.removeFromCart(listing.id);
                              },
                            ),
                            SizedBox(
                              width: 24,
                              child: Semantics(
                                label: context.tr('quantity'),
                                child: Text('$qty', textAlign: TextAlign.center, style: text.titleMedium),
                              ),
                            ),
                            IconButton(
                              key: Key('increase-${listing.id}'),
                              // Disabled once the cart holds all the stock (QA BUG-1, BUG-2).
                              tooltip: qty >= listing.quantity ? context.tr('maxStockReached') : context.tr('increase'),
                              icon: const Icon(Icons.add),
                              onPressed: qty >= listing.quantity ? null : () => app.addToCart(listing.id),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      key: Key('removeLine-${listing.id}'),
                      tooltip: context.tr('remove'),
                      icon: const Icon(Icons.delete_outline),
                      color: MashtalColors.muted,
                      onPressed: () async {
                        if (await confirmRemoveFromCart(context, plant.name(lang))) app.removeFromCart(listing.id, all: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered round marker of a pickup stop.
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.number});
  final int number;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: MashtalColors.forest, shape: BoxShape.circle),
        child: Text('$number', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MashtalColors.surface, fontWeight: FontWeight.w700)),
      );
}

/// Dashed vertical path between two pickup stops.
class DashedRail extends StatelessWidget {
  const DashedRail({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _DashPainter(), child: SizedBox.expand());
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MashtalColors.leaf
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    for (var y = 6.0; y < size.height - 4; y += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
