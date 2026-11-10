import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/catalog_search.dart';
import '../../logic/shop_filters.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/plant_photo.dart';

/// Buy Plants: search by plant or nursery with filters (US-05). Works for
/// guests (US-01).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // Kept across visits so returning from a plant page keeps the search.
  static String _savedQuery = '';

  late final _query = TextEditingController(text: _savedQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  SearchFilters get _filters {
    return shopFiltersFor(Provider.of<AppState>(context, listen: false).user);
  }

  void _setFilters(SearchFilters f) {
    final user = context.read<AppState>().user;
    setState(() => setShopFilters(user, f));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result != null) _setFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final results = searchCatalog(
      query: _query.text,
      filters: _filters,
      plants: market.plants,
      nurseries: market.nurseries,
      listings: market.listings,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // The Buy Plants tab is the home page, so it carries the logo.
        // Tapping the logo always comes back to the plants home page.
        title: InkWell(
          key: const Key('homeLogo'),
          onTap: () => context.go('/shop'),
          borderRadius: BorderRadius.circular(MashtalSpace.sm),
          child: Image.asset('assets/brand/logo_wordmark.png', height: 30, semanticLabel: context.tr('appName')),
        ),
        actions: [
          const LanguageButton(),
          if (app.user == null) TextButton(onPressed: () => context.go('/login?from=/shop'), child: Text(context.tr('signIn'))),
        ],
      ),
      body: Constrained(
        child: CustomScrollView(
          slivers: [
            if (app.role == Role.admin)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(context.tr('shopPreview')),
                    ),
                  ),
                ),
              ),
            // Sprint 2 entry point to the suitability questions (US-07).
            if (_query.text.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.lg),
                sliver: SliverToBoxAdapter(child: _ChooseBanner()),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.sm),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      // Keeps the field's accessible name once it has text
                      // (QA BUG-3); the hint alone disappears when typing.
                      child: Semantics(
                        label: context.tr('searchHint'),
                        textField: true,
                        child: TextField(
                          key: const Key('searchField'),
                          controller: _query,
                          decoration: InputDecoration(
                            hintText: context.tr('searchHint'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: context.tr('clearSearch'),
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() {
                                      _query.clear();
                                      _savedQuery = '';
                                    }),
                                  ),
                          ),
                          onChanged: (v) => setState(() => _savedQuery = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: MashtalSpace.sm),
                    Badge(
                      isLabelVisible: _filters.activeCount > 0,
                      label: Text('${_filters.activeCount}'),
                      child: IconButton.outlined(
                        key: const Key('filtersButton'),
                        tooltip: context.tr('filters'),
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune),
                        style: IconButton.styleFrom(
                          backgroundColor: _filters.isEmpty ? MashtalColors.surface : MashtalColors.mint,
                          foregroundColor: MashtalColors.forest,
                          fixedSize: const Size(48, 48),
                          side: const BorderSide(color: MashtalColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_filters.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_filters.placement != null) Chip(label: Text(context.trEnum(_filters.placement!))),
                      if (_filters.sun != null) Chip(label: Text(context.trEnum(_filters.sun!))),
                      if (_filters.water != null) Chip(label: Text('${context.tr('water')}: ${context.trEnum(_filters.water!)}')),
                      if (_filters.maxPrice != null) Chip(label: Text('${context.tr('upTo')} ${formatPrice(context, _filters.maxPrice!)}')),
                      if (_filters.city != null) Chip(label: Text(context.trCity(_filters.city!))),
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: Text(context.tr('clearFilters')),
                        onPressed: () => _setFilters(const SearchFilters()),
                      ),
                    ],
                  ),
                ),
              ),
            if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.search_off, title: context.tr('noResults')),
              ),
            if (results.plants.isNotEmpty) _header(context, context.tr('plants'), results.plants.length),
            // Browsing: one shelf per plant type that swipes sideways, the first
            // shelf with bigger cards. Searching or filtering shows the grid.
            if (_query.text.isEmpty && _filters.isEmpty)
              for (final (i, (category, plants)) in _shelves(results.plants).indexed)
                SliverToBoxAdapter(
                  child: _Shelf(title: context.tr('shelf_${category.name}'), plants: plants, large: i == 0),
                )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  // Two photo cards per row on phones, three on wide web.
                  final columns = constraints.crossAxisExtent >= 600 ? 3 : 2;
                  final rows = (results.plants.length / columns).ceil();
                  return SliverList.separated(
                    itemCount: rows,
                    separatorBuilder: (_, _) => const SizedBox(height: MashtalSpace.md),
                    itemBuilder: (_, r) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.screen),
                      // Equal-height cards in a row, so prices line up.
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var c = 0; c < columns; c++) ...[
                              if (c > 0) const SizedBox(width: MashtalSpace.md),
                              Expanded(
                                child: r * columns + c < results.plants.length
                                    ? _PlantCard(result: results.plants[r * columns + c])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (results.nurseries.isNotEmpty) _header(context, context.tr('nurseries'), results.nurseries.length),
            SliverList.separated(
              itemCount: results.nurseries.length,
              separatorBuilder: (_, _) => const SizedBox(height: MashtalSpace.sm),
              itemBuilder: (_, i) {
                final n = results.nurseries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.screen),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                        child: const Icon(Icons.storefront_outlined),
                      ),
                      title: Text(n.name(context.lang)),
                      subtitle: Text('${context.trCity(n.city)} · ${n.district}'),
                      trailing: RatingLabel(rating: n.rating),
                      onTap: () => context.go('/shop/nursery/${n.id}'),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: MashtalSpace.xl)),
            // Room to scroll the last row clear of the floating navigation.
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title, int count) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xl, MashtalSpace.screen, MashtalSpace.md),
    sliver: SliverToBoxAdapter(child: Text('$title ($count)', style: Theme.of(context).textTheme.titleLarge)),
  );
}

/// Entry point to the suitability questions (US-07): the one strong block on
/// the shop, carrying the screen's single primary (emerald) action.
class _ChooseBanner extends StatelessWidget {
  const _ChooseBanner();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // A soft mint wave with a young tree on the end side: the green backdrop
    // that says "this is about what grows at your place".
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('chooseBanner'),
        onTap: () => context.go('/choose'),
        borderRadius: BorderRadius.circular(MashtalSpace.radius),
        child: CustomPaint(
          painter: _WavePainter(rtl: Directionality.of(context) == TextDirection.rtl),
          child: Stack(
            children: [
              PositionedDirectional(
                end: MashtalSpace.lg,
                bottom: MashtalSpace.xl,
                child: ExcludeSemantics(child: Image.asset('assets/brand/banner_tree.png', height: 116)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(MashtalSpace.lg, MashtalSpace.xl, 112, MashtalSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('chooseBannerTitle'), style: text.titleLarge),
                    const SizedBox(height: MashtalSpace.xs),
                    Text(context.tr('chooseBannerBody'), style: text.bodyMedium?.copyWith(color: MashtalColors.forestDeep)),
                    const SizedBox(height: MashtalSpace.lg),
                    FilledButton(
                      // The theme makes filled buttons full width; size this one to its label.
                      style: FilledButton.styleFrom(minimumSize: const Size(128, 48)),
                      onPressed: () => context.go('/choose'),
                      child: Text(context.tr('chooseStart')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mint panel with a gently waving bottom edge.
class _WavePainter extends CustomPainter {
  const _WavePainter({required this.rtl});
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const r = MashtalSpace.radius;
    final panel = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - 28)
      ..cubicTo(w * 0.72, h + 6, w * 0.38, h - 34, 0, h - 8)
      ..close();
    canvas.drawPath(
      panel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MashtalColors.mint, MashtalColors.ground],
        ).createShader(Offset.zero & size),
    );

  }

  @override
  bool shouldRepaint(_WavePainter old) => old.rtl != rtl;
}

/// Photo-first plant card: square photo, name, botanical name, one line of
/// facts, then the lowest price.
class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.result});
  final PlantResult result;

  @override
  Widget build(BuildContext context) {
    final p = result.plant;
    final text = Theme.of(context).textTheme;
    final price = result.lowestPrice;
    final inStock = result.offers.where((o) => o.listing.isAvailable).toList()..sort((a, b) => a.listing.price.compareTo(b.listing.price));
    final cheapest = inStock.isEmpty ? null : inStock.first.listing;
    // Only nurseries with the plant in stock count (QA BUG-5).
    final nurseries = result.offers.where((o) => o.listing.isAvailable).map((o) => o.nursery.id).toSet().length;
    // White product box with a soft shadow; the photo sits inset with its own
    // rounded corners, then name, facts, price and one emerald dot.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MashtalColors.surface,
        borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
        boxShadow: const [BoxShadow(color: MashtalColors.shadow, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.go('/shop/plant/${p.id}'),
          borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(MashtalSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: PlantPhoto.fill(plant: p, radius: MashtalSpace.radius),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(MashtalSpace.xs, MashtalSpace.sm, MashtalSpace.xs, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name(context.lang), style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          p.scientificName,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: MashtalSpace.xs),
                        Text(
                          '${context.trEnum(p.sun)} · ${context.tr('water')}: ${context.trEnum(p.water)}${nurseries == 0 ? '' : ' · ${nurseries == 1 ? context.tr('oneNursery') : '$nurseries ${context.tr('nurseriesCount')}'}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                        const Spacer(),
                        const SizedBox(height: MashtalSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: price == null
                                  ? Text(context.tr('notAvailable'), style: text.labelMedium?.copyWith(color: MashtalColors.error))
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(context.tr('from'), style: text.bodySmall),
                                        const SizedBox(width: MashtalSpace.xs),
                                        Flexible(
                                          child: Text(
                                            formatPrice(context, price),
                                            style: text.titleLarge?.copyWith(color: MashtalColors.forestDeep),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            // Quick add: the cheapest in-stock offer, the same one the
                            // "from" price shows. Opening the card still compares nurseries.
                            if (cheapest != null && context.watch<AppState>().canShop) _QuickAdd(listing: cheapest),
                          ],
                        ),
                      ],
                    ),
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

/// Round emerald "+" on a product box: adds that offer to the cart.
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key('quickAdd-${listing.id}'),
    tooltip: context.tr('addToCart'),
    padding: EdgeInsets.zero,
    // 48x48 tap area around a 36 px dot.
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: const DecoratedBox(
      decoration: BoxDecoration(gradient: MashtalColors.emeraldBlend, shape: BoxShape.circle),
      child: SizedBox.square(dimension: 36, child: Icon(Icons.add, size: 22, color: MashtalColors.forestDeep)),
    ),
    onPressed: () {
      final added = context.read<AppState>().addToCart(listing.id);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr(added ? 'addedToCart' : 'maxStockReached')), duration: const Duration(seconds: 1)),
        );
    },
  );
}

/// Plants grouped by type, in the order a Riyadh household browses them.
List<(PlantCategory, List<PlantResult>)> _shelves(List<PlantResult> plants) => [
  for (final c in const [
    PlantCategory.palm,
    PlantCategory.tree,
    PlantCategory.houseplant,
    PlantCategory.shrub,
    PlantCategory.succulent,
    PlantCategory.herb,
    PlantCategory.climber,
    PlantCategory.groundcover,
    PlantCategory.grass,
  ])
    if (plants.where((r) => r.plant.category == c).toList() case final list when list.isNotEmpty) (c, list),
];

/// One titled row of product boxes that swipes sideways.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.plants, required this.large});
  final String title;
  final List<PlantResult> plants;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final width = large ? 220.0 : 164.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.lg, MashtalSpace.screen, MashtalSpace.sm),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        // A short row (a few boxes per type), so build it all and let the
        // boxes share the height of the tallest one.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Room for the boxes' shadows.
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.lg),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, r) in plants.indexed) ...[
                  if (i > 0) const SizedBox(width: MashtalSpace.md),
                  SizedBox(
                    width: width,
                    child: _PlantCard(result: r),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final SearchFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters f = widget.initial;
  late final _priceText = TextEditingController(text: _fmt(f.maxPrice));

  /// Slider stops; the last stop means "any price" (feedback 2).
  static const _priceSteps = [10.0, 15.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _priceText.dispose();
    super.dispose();
  }

  /// Slider position for a price: the first stop at or above it.
  double get _sliderIndex {
    final max = f.maxPrice;
    if (max == null) return _priceSteps.length.toDouble();
    final i = _priceSteps.indexWhere((s) => s >= max);
    return (i < 0 ? _priceSteps.length - 1 : i).toDouble();
  }

  void _setMaxPrice(double? v) {
    setState(() => f = f.copyWith(maxPrice: () => v));
  }

  Widget _priceSlider(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [..._priceSteps.map((s) => _fmt(s)), context.tr('any')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Text(context.tr('maxPrice'), style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                f.maxPrice == null ? context.tr('anyPrice') : '${context.tr('upTo')} ${formatPrice(context, f.maxPrice!)}',
                key: const Key('maxPriceLabel'),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        Slider(
          key: const Key('priceSlider'),
          value: _sliderIndex,
          min: 0,
          max: _priceSteps.length.toDouble(),
          divisions: _priceSteps.length,
          label: _sliderIndex.round() == _priceSteps.length
              ? context.tr('anyPrice')
              : formatPrice(context, _priceSteps[_sliderIndex.round()]),
          onChanged: (v) {
            final i = v.round();
            final price = i >= _priceSteps.length ? null : _priceSteps[i];
            _priceText.text = _fmt(price);
            _setMaxPrice(price);
          },
        ),
        // Visible stops under the slider.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final l in labels) Text(l, style: theme.textTheme.labelSmall)],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('maxPriceField'),
          controller: _priceText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: context.tr('typeMaxPrice'), suffixText: context.tr('sar'), isDense: true),
          onChanged: (v) {
            final price = double.tryParse(v);
            _setMaxPrice(price != null && price > 0 ? price : null);
          },
        ),
      ],
    );
  }

  Widget _group<T>(String title, List<T> values, T? selected, String Function(T) label, void Function(T?) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(label: Text(context.tr('any')), selected: selected == null, onSelected: (_) => onSelect(null)),
            for (final v in values) ChoiceChip(label: Text(label(v)), selected: selected == v, onSelected: (_) => onSelect(v)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('filters'), style: Theme.of(context).textTheme.titleLarge),
            _group<Placement>(
              context.tr('placement'),
              Placement.values,
              f.placement,
              context.trEnum,
              (v) => setState(() => f = f.copyWith(placement: () => v)),
            ),
            _group<Sun>(context.tr('sun'), Sun.values, f.sun, context.trEnum, (v) => setState(() => f = f.copyWith(sun: () => v))),
            _group<Water>(
              context.tr('water'),
              Water.values,
              f.water,
              context.trEnum,
              (v) => setState(() => f = f.copyWith(water: () => v)),
            ),
            _priceSlider(context),
            _group<String>(context.tr('city'), cityIds, f.city, context.trCity, (v) => setState(() => f = f.copyWith(city: () => v))),
            const SizedBox(height: 20),
            FilledButton(key: const Key('applyFilters'), onPressed: () => Navigator.pop(context, f), child: Text(context.tr('apply'))),
            TextButton(onPressed: () => Navigator.pop(context, const SearchFilters()), child: Text(context.tr('clearFilters'))),
          ],
        ),
      ),
    ),
  );
}
