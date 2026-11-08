import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/plant_photo.dart';

/// Minimal cart so a guest's choices survive sign-in (US-01 AC-02). Grouping
/// by nursery and reserving are Sprint 3 (US-15, US-16).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final lines = [
      for (final MapEntry(key: id, value: qty) in app.cart.entries)
        if (market.listings.where((l) => l.id == id).firstOrNull case final listing?)
          (listing, qty, market.plantById(listing.plantId)!, market.nurseryById(listing.nurseryId)!),
    ];
    final total = lines.fold<double>(0, (sum, l) => sum + l.$1.price * l.$2);
    if (app.cartAdjusted) {
      app.cartAdjusted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('cartAdjusted'))));
      });
    }

    void reserve() {
      if (app.user == null) {
        context.go('/login?from=/cart');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('reserveSoon'))));
      }
    }

    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('cart')), actions: const [LanguageButton()]),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_basket_outlined,
              title: context.tr('cartEmpty'),
              actions: [OutlinedButton(onPressed: () => context.go('/shop'), child: Text(context.tr('buyPlants')))],
            )
          : Constrained(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl),
                children: [
                  for (final (listing, qty, plant, nursery) in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MashtalSpace.md),
                      // Frameless white line on the page, photo tile first, like the shop.
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                        child: Padding(
                          padding: const EdgeInsets.all(MashtalSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PlantPhoto(plant: plant, listingPhoto: listing.photo, size: 88),
                                  const SizedBox(width: MashtalSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(plant.name(lang), style: text.titleMedium),
                                        const SizedBox(height: MashtalSpace.xs),
                                        Text(
                                          '${nursery.name(lang)} · ${formatPrice(context, listing.price)}\n${context.tr('onlyLeft')}: ${listing.quantity}',
                                          style: text.bodyMedium?.copyWith(color: MashtalColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: MashtalSpace.sm),
                              Row(
                                children: [
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
                                          onPressed: () => app.removeFromCart(listing.id),
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
                                    onPressed: () => app.removeFromCart(listing.id, all: true),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Total and the screen's one primary action. Kept in the list,
                  // not pinned to the bottom, so the "added" message never covers it.
                  const SizedBox(height: MashtalSpace.sm),
                  Card(
                    color: MashtalColors.ground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                    child: Padding(
                      padding: const EdgeInsets.all(MashtalSpace.lg),
                      child: Row(
                        children: [
                          Text(formatPrice(context, total), style: text.titleLarge?.copyWith(color: MashtalColors.forestDeep)),
                          const SizedBox(width: MashtalSpace.lg),
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('reserve'),
                              icon: const Icon(Icons.event_available),
                              label: Text(context.tr('reserve')),
                              onPressed: reserve,
                            ),
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
