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

/// How a listing's stock reads at a glance.
enum Stock { inStock, low, out, hidden }

/// Five or fewer left counts as running low.
const lowStock = 5;

Stock stockOf(Listing l) => l.hidden
    ? Stock.hidden
    : l.quantity == 0
        ? Stock.out
        : l.quantity <= lowStock
            ? Stock.low
            : Stock.inStock;

/// The filters on top of the grid.
enum StockFilter { all, inStock, low, outOrHidden }

bool passes(Listing l, StockFilter f) => switch (f) {
      StockFilter.all => true,
      StockFilter.inStock => stockOf(l) == Stock.inStock,
      StockFilter.low => stockOf(l) == Stock.low,
      StockFilter.outOrHidden => stockOf(l) == Stock.out || stockOf(l) == Stock.hidden,
    };

String _filterKey(StockFilter f) => switch (f) {
      StockFilter.all => 'filterAll',
      StockFilter.inStock => 'filterIn',
      StockFilter.low => 'filterLow',
      StockFilter.outOrHidden => 'filterOut',
    };

/// Nursery home: its listings as a photo grid, each with its stock on the
/// photo, and filters for what needs attention (US-06).
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  StockFilter _filter = StockFilter.all;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final nursery = app.user?.partnerId == null ? null : market.nurseryById(app.user!.partnerId!);
    if (nursery == null) return const SizedBox.shrink();
    final lang = context.lang;
    final theme = Theme.of(context);
    final listings = market.listings.where((l) => l.nurseryId == nursery.id).toList();
    final shown = [
      for (final l in listings)
        if (passes(l, _filter))
          if (market.plantById(l.plantId) case final plant?) (listing: l, plant: plant),
    ]..sort((a, b) => a.plant.name(lang).compareTo(b.plant.name(lang)));

    return Scaffold(
      appBar: AppBar(
        title: Text(nursery.name(lang)),
        actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: StatusChip(status: nursery.status)), const LanguageButton()],
      ),
      // Lifted above the floating navigation, which the page scrolls under.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          key: const Key('addListing'),
          onPressed: () => context.go('/nursery/listing/new'),
          icon: const Icon(Icons.add),
          label: Text(context.tr('addListing')),
        ),
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(16, 8, 16, 96)),
          children: [
            if (!nursery.isVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: MashtalColors.sand,
                  child: ListTile(leading: const Icon(Icons.hourglass_top), title: Text(context.tr('pendingNursery'))),
                ),
              ),
            Text('${context.tr('myListings')} (${listings.length})', style: theme.textTheme.titleLarge),
            const SizedBox(height: MashtalSpace.md),
            if (listings.isEmpty)
              EmptyState(icon: Icons.inventory_2_outlined, art: Art.basket, title: context.tr('noListings'))
            else ...[
              // What needs attention, with how many are in each group.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in StockFilter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: MashtalSpace.sm),
                        child: ChoiceChip(
                          key: Key('filter-${f.name}'),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.tr(_filterKey(f))),
                              const SizedBox(width: MashtalSpace.sm),
                              // How many are in this group, as a small count.
                              Container(
                                constraints: const BoxConstraints(minWidth: 22),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _filter == f ? MashtalColors.surface : MashtalColors.ground,
                                  borderRadius: BorderRadius.circular(MashtalSpace.pill),
                                ),
                                child: Text('${listings.where((l) => passes(l, f)).length}', textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                              ),
                            ],
                          ),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MashtalSpace.lg),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(MashtalSpace.xl),
                  child: Text(context.tr('noListingsHere'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                ),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = MashtalSpace.md;
                  final columns = c.maxWidth >= 560 ? 3 : 2;
                  final width = (c.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [for (final s in shown) SizedBox(width: width, child: _ListingTile(listing: s.listing, plant: s.plant))],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One listing: its photo with the stock on it, the name and the price.
class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.listing, required this.plant});
  final Listing listing;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stock = stockOf(listing);
    final (label, bg, fg) = switch (stock) {
      Stock.inStock => (context.tr('stockIn').replaceAll('{n}', '${listing.quantity}'), MashtalColors.mint, MashtalColors.forest),
      Stock.low => (context.tr('stockLow').replaceAll('{n}', '${listing.quantity}'), MashtalColors.sand, MashtalColors.forestDeep),
      Stock.out => (context.tr('soldOut'), MashtalColors.errorSoft, MashtalColors.error),
      Stock.hidden => (context.tr('hidden'), MashtalColors.line, MashtalColors.forestDeep),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MashtalColors.surface,
        borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
        boxShadow: const [BoxShadow(color: MashtalColors.shadow, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('listing-${listing.id}'),
          borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
          onTap: () => context.go('/nursery/listing/${listing.id}'),
          child: Padding(
            padding: const EdgeInsets.all(MashtalSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: listing.isAvailable ? 1 : 0.45,
                        child: PlantPhoto.fill(plant: plant, listingPhoto: listing.photo, radius: MashtalSpace.radius),
                      ),
                      PositionedDirectional(
                        top: MashtalSpace.sm,
                        start: MashtalSpace.sm,
                        child: Container(
                          key: Key('stock-${listing.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.xs),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MashtalSpace.pill)),
                          child: Text(label, style: text.labelLarge?.copyWith(color: fg)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(MashtalSpace.xs, MashtalSpace.sm, MashtalSpace.xs, MashtalSpace.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plant.name(context.lang), style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: MashtalSpace.xs),
                      Row(
                        children: [
                          Expanded(child: Text(formatPrice(context, listing.price), style: text.titleLarge?.copyWith(color: MashtalColors.forestDeep))),
                          const Icon(Icons.edit_outlined, size: 18, color: MashtalColors.leaf),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
