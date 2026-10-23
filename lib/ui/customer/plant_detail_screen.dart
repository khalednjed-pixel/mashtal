import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/not_found.dart';

/// A plant, what it needs, and the verified nurseries that sell it.
class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final plant = market.plantById(plantId);
    if (plant == null) return const NotFoundScreen();
    final theme = Theme.of(context);
    final lang = context.lang;

    final offers = [
      for (final l in market.listings)
        if (l.plantId == plantId && !l.hidden)
          if (market.nurseryById(l.nurseryId) case final n? when n.isVerified) (l, n),
    ]..sort((a, b) {
        if (a.$1.isAvailable != b.$1.isAvailable) return a.$1.isAvailable ? -1 : 1;
        return a.$1.price.compareTo(b.$1.price);
      });

    return Scaffold(
      appBar: AppBar(title: Text(plant.name(lang)), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                PlantAvatar(plant: plant, size: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plant.name(lang), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(plant.scientificName, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                      Text(context.trEnum(plant.category), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(plant.description(lang), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in plant.placements) Chip(avatar: const Icon(Icons.place_outlined, size: 18), label: Text(context.trEnum(p))),
                Chip(avatar: const Icon(Icons.wb_sunny_outlined, size: 18), label: Text(context.trEnum(plant.sun))),
                Chip(avatar: const Icon(Icons.water_drop_outlined, size: 18), label: Text('${context.tr('water')}: ${context.trEnum(plant.water)}')),
                Chip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text('${context.tr('waterEvery')} ${plant.wateringEveryDays} ${context.tr('days')}'),
                ),
              ],
            ),
            if (plant.toxic) ...[
              const SizedBox(height: 8),
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(leading: const Icon(Icons.warning_amber_rounded), title: Text(context.tr('toxicWarning'))),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${context.tr('source')}: ${plant.source}${plant.guideBacked ? '' : ' — ${context.tr('notGuideBacked')}'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(context.tr('whereToBuy'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (offers.isEmpty) Text(context.tr('notAvailable')),
            for (final (listing, nursery) in offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => context.go('/shop/nursery/${nursery.id}'),
                    title: Text(nursery.name(lang)),
                    subtitle: Row(
                      children: [
                        RatingLabel(rating: nursery.rating),
                        Text('  ·  ${context.trCity(nursery.city)}'),
                      ],
                    ),
                    trailing: _OfferAction(listing: listing),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferAction extends StatelessWidget {
  const _OfferAction({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!listing.isAvailable) {
      return Text(context.tr('notAvailable'), style: TextStyle(color: theme.colorScheme.error));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatPrice(context, listing.price), style: theme.textTheme.titleSmall),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          key: Key('add-${listing.id}'),
          tooltip: context.tr('addToCart'),
          icon: const Icon(Icons.add_shopping_cart),
          onPressed: () {
            context.read<AppState>().addToCart(listing.id);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(context.tr('addedToCart')), duration: const Duration(seconds: 1)));
          },
        ),
      ],
    );
  }
}
