import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/catalog_search.dart';
import '../../logic/shop_filters.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/garden_art.dart';
import '../widgets/plant_photo.dart';
import '../widgets/save_button.dart';

/// Plants the customer (or guest) saved with the heart, newest first, each
/// with its lowest price and how many nurseries have it in stock.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final ids = app.savedPlantIds;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/shop')),
        title: Text(context.tr('savedPlants')),
        actions: const [LanguageButton()],
      ),
      body: ids.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border,
              art: Art.savedLeaf,
              title: context.tr('noSaved'),
              body: context.tr('noSavedBody'),
              actions: [OutlinedButton(onPressed: () => context.go('/shop'), child: Text(context.tr('browseShop')))],
            )
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
                children: [
                  for (final id in ids)
                    if (market.plantById(id) case final p?)
                      Padding(
                        key: Key('saved-$id'),
                        padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(MashtalSpace.radius),
                            onTap: () => context.go('/shop/plant/$id'),
                            child: Padding(
                              padding: const EdgeInsets.all(MashtalSpace.sm),
                              child: Row(
                                children: [
                                  PlantPhoto(plant: p, size: 72),
                                  const SizedBox(width: MashtalSpace.md),
                                  Expanded(
                                    child: Builder(builder: (context) {
                                      final inStock = [
                                        for (final o in customerOffers(listings: market.listings, nurseryById: market.nurseryById, plantId: id, city: preferredCity(app.user)))
                                          if (o.listing.isAvailable) o,
                                      ];
                                      final price = inStock.isEmpty ? null : inStock.map((o) => o.listing.price).reduce((a, b) => a < b ? a : b);
                                      final nurseries = inStock.map((o) => o.nursery.id).toSet().length;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name(lang), style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: MashtalSpace.xs),
                                          if (price == null)
                                            Text(context.tr('notAvailable'), style: text.labelMedium?.copyWith(color: MashtalColors.error))
                                          else
                                            Text.rich(
                                              TextSpan(children: [
                                                TextSpan(text: '${context.tr('from')} ', style: text.bodySmall),
                                                TextSpan(text: formatPrice(context, price), style: text.titleMedium?.copyWith(color: MashtalColors.forestDeep)),
                                                TextSpan(
                                                  text: '  ·  ${context.trCount('nurseryCount', nurseries)}',
                                                  style: text.bodySmall,
                                                ),
                                              ]),
                                            ),
                                        ],
                                      );
                                    }),
                                  ),
                                  SaveButton(plantId: id),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
