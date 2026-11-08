import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/catalog_search.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/plant_photo.dart';
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
      for (final o in customerOffers(listings: market.listings, nurseryById: market.nurseryById, plantId: plantId))
        (o.listing, o.nursery),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name(lang)),
        actions: [
          // The admin removes plants that nurseries added (feedback 9).
          if (app.role == Role.admin && plant.isCustom)
            IconButton(
              key: const Key('deletePlant'),
              tooltip: context.tr('deletePlant'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, plant.name(lang))) return;
                await market.deletePlant(plant.id);
                if (context.mounted) context.go('/shop');
              },
            ),
          const LanguageButton(),
        ],
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xxl),
          children: [
            // Detail photos: fixed 4:3, cropped to cover. Swipe sideways to see
            // the nurseries' own photos of this plant; the credit stays underneath.
            _PhotoGallery(plant: plant, listingPhotos: [for (final (l, _) in offers) if (l.photo != null) l.photo!]),
            const SizedBox(height: MashtalSpace.sm),
            Text(plant.name(lang), style: theme.textTheme.headlineSmall),
            const SizedBox(height: MashtalSpace.xs),
            // LTR inside RTL, but kept on the same (start) edge as the name.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                plant.scientificName,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
            Text(context.trEnum(plant.category), style: theme.textTheme.bodySmall),
            const SizedBox(height: MashtalSpace.lg),
            Text(plant.description(lang), style: theme.textTheme.bodyLarge),
            const SizedBox(height: MashtalSpace.lg),
            // What it needs, as one calm mint panel of rows instead of a row of chips.
            Card(
              color: MashtalColors.ground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
              child: Column(
                children: [
                  for (final (i, (icon, label)) in [
                    for (final p in plant.placements) (Icons.place_outlined, context.trEnum(p)),
                    (Icons.wb_sunny_outlined, context.trEnum(plant.sun)),
                    (Icons.water_drop_outlined, '${context.tr('water')}: ${context.trEnum(plant.water)}'),
                    (Icons.schedule, '${context.tr('waterEvery')} ${plant.wateringEveryDays} ${context.tr('days')}'),
                  ].indexed) ...[
                    if (i > 0) const Divider(indent: MashtalSpace.lg, endIndent: MashtalSpace.lg, color: MashtalColors.surface),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.lg, vertical: MashtalSpace.md),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: MashtalColors.leaf),
                          const SizedBox(width: MashtalSpace.md),
                          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (plant.toxic) ...[
              const SizedBox(height: MashtalSpace.md),
              Container(
                padding: const EdgeInsets.all(MashtalSpace.md),
                decoration: BoxDecoration(color: MashtalColors.errorSoft, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: MashtalColors.error),
                    const SizedBox(width: MashtalSpace.md),
                    Expanded(child: Text(context.tr('toxicWarning'), style: theme.textTheme.labelLarge?.copyWith(color: MashtalColors.error))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MashtalSpace.md),
            Container(
              padding: const EdgeInsets.all(MashtalSpace.md),
              decoration: BoxDecoration(border: Border.all(color: MashtalColors.line), borderRadius: BorderRadius.circular(MashtalSpace.radius)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(plant.guideBacked ? Icons.menu_book_outlined : Icons.info_outline, size: 20, color: MashtalColors.leaf),
                  const SizedBox(width: MashtalSpace.sm),
                  Expanded(
                    child: Text(
                      plant.isCustom
                          ? context.tr('addedByNursery')
                          : '${context.tr('source')}: ${sourceText(lang, plant)}${plant.guideBacked ? '' : ' — ${context.tr('notGuideBacked')}'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: MashtalColors.forestDeep),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MashtalSpace.xl),
            Text(context.tr('whereToBuy'), style: theme.textTheme.titleLarge),
            const SizedBox(height: MashtalSpace.md),
            if (offers.isEmpty) Text(context.tr('notAvailable'), style: theme.textTheme.bodyLarge?.copyWith(color: MashtalColors.muted)),
            for (final (listing, nursery) in offers)
              Padding(
                padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                child: Card(
                  child: InkWell(
                    onTap: () => context.go('/shop/nursery/${nursery.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(MashtalSpace.md),
                      child: Row(
                        children: [
                          if (listing.photo != null) ...[
                            PlantPhoto(plant: plant, listingPhoto: listing.photo, size: 48),
                            const SizedBox(width: MashtalSpace.md),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nursery.name(lang), style: theme.textTheme.titleMedium),
                                const SizedBox(height: MashtalSpace.xs),
                                Row(
                                  children: [
                                    RatingLabel(rating: nursery.rating),
                                    Flexible(child: Text('  ·  ${context.trCity(nursery.city)}', style: theme.textTheme.bodyMedium?.copyWith(color: MashtalColors.muted))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: MashtalSpace.sm),
                          _OfferAction(listing: listing),
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

class _OfferAction extends StatelessWidget {
  const _OfferAction({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!listing.isAvailable) {
      return Text(context.tr('notAvailable'), style: theme.textTheme.labelMedium?.copyWith(color: MashtalColors.error));
    }
    final price = Text(formatPrice(context, listing.price), style: theme.textTheme.titleLarge?.copyWith(color: MashtalColors.forestDeep));
    if (!context.watch<AppState>().canShop) return price;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        price,
        const SizedBox(width: MashtalSpace.sm),
        // Round emerald add button, the same mark as the shop cards' dot.
        IconButton.filled(
          key: Key('add-${listing.id}'),
          tooltip: context.tr('addToCart'),
          icon: const Icon(Icons.add_shopping_cart, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: MashtalColors.emerald,
            foregroundColor: MashtalColors.forestDeep,
            fixedSize: const Size(48, 48),
          ).copyWith(
            backgroundBuilder: (context, states, child) => DecoratedBox(
              decoration: const BoxDecoration(gradient: MashtalColors.emeraldBlend, shape: BoxShape.circle),
              child: child,
            ),
          ),
          onPressed: () {
            final added = context.read<AppState>().addToCart(listing.id);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(context.tr(added ? 'addedToCart' : 'maxStockReached')),
                duration: const Duration(seconds: 1),
              ));
          },
        ),
      ],
    );
  }
}

/// The plant's photo plus any nursery photos, swiped sideways with page dots.
class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.plant, required this.listingPhotos});
  final Plant plant;
  final List<String> listingPhotos;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = <String?>[null, ...widget.listingPhotos]; // null: the plant's own photo
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: photos.length == 1
              ? PlantPhoto.fill(plant: widget.plant, radius: MashtalSpace.radius)
              : PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PlantPhoto.fill(plant: widget.plant, listingPhoto: photos[i], radius: MashtalSpace.radius),
                  ),
                ),
        ),
        Row(
          children: [
            // The licence credit belongs to the Commons photo only.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _page == 0 ? PhotoCredit(plant: widget.plant) : const SizedBox(height: 32),
              ),
            ),
            if (photos.length > 1)
              for (var i = 0; i < photos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsetsDirectional.only(start: MashtalSpace.xs),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: ShapeDecoration(shape: const StadiumBorder(), color: i == _page ? MashtalColors.emerald : MashtalColors.mint),
                ),
          ],
        ),
      ],
    );
  }
}
