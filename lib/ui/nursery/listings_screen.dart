import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Nursery home: its listings, prices and availability (US-06).
class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final nursery = app.user?.partnerId == null ? null : market.nurseryById(app.user!.partnerId!);
    if (nursery == null) return const SizedBox.shrink();
    final lang = context.lang;
    final theme = Theme.of(context);
    final listings = market.listings.where((l) => l.nurseryId == nursery.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(nursery.name(lang)),
        actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: StatusChip(status: nursery.status)), const LanguageButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addListing'),
        onPressed: () => context.go('/nursery/listing/new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr('addListing')),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!nursery.isVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: const Color(0xFFFFF0C9),
                  child: ListTile(leading: const Icon(Icons.hourglass_top), title: Text(context.tr('pendingNursery'))),
                ),
              ),
            Text('${context.tr('myListings')} (${listings.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (listings.isEmpty) EmptyState(icon: Icons.inventory_2_outlined, title: context.tr('noListings')),
            for (final l in listings)
              if (market.plantById(l.plantId) case final plant?) _ListingTile(listing: l, plant: plant),
          ],
        ),
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.listing, required this.plant});
  final Listing listing;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = listing.hidden
        ? context.tr('hidden')
        : listing.quantity == 0
            ? context.tr('notAvailable')
            : '${context.tr('qtyShort')}: ${listing.quantity}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          key: Key('listing-${listing.id}'),
          leading: Opacity(opacity: listing.isAvailable ? 1 : 0.4, child: PlantAvatar(plant: plant, size: 44)),
          title: Text(plant.name(context.lang)),
          subtitle: Text(status, style: TextStyle(color: listing.isAvailable ? null : theme.colorScheme.error)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatPrice(context, listing.price), style: theme.textTheme.titleSmall),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => context.go('/nursery/listing/${listing.id}'),
        ),
      ),
    );
  }
}
