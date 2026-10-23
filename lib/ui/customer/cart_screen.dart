import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
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
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (listing, qty, plant, nursery) in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: PlantPhoto(plant: plant, listingPhoto: listing.photo, size: 48),
                          title: Text(plant.name(lang)),
                          subtitle: Text('${nursery.name(lang)} · ${formatPrice(context, listing.price)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => app.removeFromCart(listing.id)),
                              Text('$qty'),
                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => app.addToCart(listing.id)),
                              IconButton(
                                key: Key('removeLine-${listing.id}'),
                                tooltip: context.tr('remove'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => app.removeFromCart(listing.id, all: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(formatPrice(context, total), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.end),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('reserve'),
                    icon: const Icon(Icons.event_available),
                    label: Text(context.tr('reserve')),
                    onPressed: () {
                      if (app.user == null) {
                        context.go('/login?from=/cart');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('reserveSoon'))));
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
