import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/catalog_search.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
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

  /// Filters per account. A signed-in user starts filtered to their own city
  /// and can change it (feedback 3).
  static final Map<String, SearchFilters> _savedFilters = {};

  late final _query = TextEditingController(text: _savedQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  SearchFilters get _filters {
    final user = Provider.of<AppState>(context, listen: false).user;
    return _savedFilters.putIfAbsent(user?.id ?? 'guest', () => SearchFilters(city: user?.city));
  }

  void _setFilters(SearchFilters f) {
    final user = context.read<AppState>().user;
    setState(() => _savedFilters[user?.id ?? 'guest'] = f);
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
        title: Image.asset('assets/brand/logo_wordmark.png', height: 30, semanticLabel: context.tr('appName')),
        actions: [
          const LanguageButton(),
          if (app.user == null)
            TextButton(onPressed: () => context.go('/login?from=/shop'), child: Text(context.tr('signIn'))),
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
                    child: ListTile(dense: true, leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(context.tr('shopPreview'))),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('searchField'),
                        controller: _query,
                        decoration: InputDecoration(
                          hintText: context.tr('searchHint'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.text.isEmpty
                              ? null
                              : IconButton(
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
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _filters.activeCount > 0,
                      label: Text('${_filters.activeCount}'),
                      child: IconButton.filledTonal(
                        key: const Key('filtersButton'),
                        tooltip: context.tr('filters'),
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune),
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
            SliverList.separated(
              itemCount: results.plants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PlantCard(result: results.plants[i]),
              ),
            ),
            if (results.nurseries.isNotEmpty) _header(context, context.tr('nurseries'), results.nurseries.length),
            SliverList.separated(
              itemCount: results.nurseries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = results.nurseries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: theme.colorScheme.secondaryContainer, child: const Icon(Icons.storefront)),
                      title: Text(n.name(context.lang)),
                      subtitle: Text('${context.trCity(n.city)} · ${n.district}'),
                      trailing: RatingLabel(rating: n.rating),
                      onTap: () => context.go('/shop/nursery/${n.id}'),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title, int count) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text('$title ($count)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.result});
  final PlantResult result;

  @override
  Widget build(BuildContext context) {
    final p = result.plant;
    final theme = Theme.of(context);
    final price = result.lowestPrice;
    final nurseries = result.offers.map((o) => o.nursery.id).toSet().length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/shop/plant/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PlantPhoto(plant: p),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name(context.lang), style: theme.textTheme.titleMedium),
                    Text(p.scientificName, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text(
                      '${context.trEnum(p.sun)} · ${context.tr('water')}: ${context.trEnum(p.water)} · ${nurseries == 1 ? context.tr('oneNursery') : '$nurseries ${context.tr('nurseriesCount')}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              price == null
                  ? Text(context.tr('notAvailable'), style: TextStyle(color: theme.colorScheme.error))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.tr('from'), style: theme.textTheme.bodySmall),
                        Text(formatPrice(context, price), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
            ],
          ),
        ),
      ),
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
          label: _sliderIndex.round() == _priceSteps.length ? context.tr('anyPrice') : formatPrice(context, _priceSteps[_sliderIndex.round()]),
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
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(label: Text(context.tr('any')), selected: selected == null, onSelected: (_) => onSelect(null)),
            for (final v in values)
              ChoiceChip(label: Text(label(v)), selected: selected == v, onSelected: (_) => onSelect(v)),
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
                _group<Placement>(context.tr('placement'), Placement.values, f.placement, context.trEnum,
                    (v) => setState(() => f = f.copyWith(placement: () => v))),
                _group<Sun>(context.tr('sun'), Sun.values, f.sun, context.trEnum, (v) => setState(() => f = f.copyWith(sun: () => v))),
                _group<Water>(context.tr('water'), Water.values, f.water, context.trEnum,
                    (v) => setState(() => f = f.copyWith(water: () => v))),
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
