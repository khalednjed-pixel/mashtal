import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/text_match.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Add or edit a listing. The plant always comes from the plant list so every
/// listing links to its knowledge-base record (US-06 AC-01).
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  /// Null when adding a new listing.
  final String? listingId;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  late final AppState _app = context.read<AppState>();
  late final Listing? _existing =
      widget.listingId == null ? null : _app.backend.listings.where((l) => l.id == widget.listingId).firstOrNull;

  late String? _plantId = _existing?.plantId;
  late final _price = TextEditingController(text: _existing == null ? '' : _formatNumber(_existing.price));
  late final _quantity = TextEditingController(text: _existing?.quantity.toString() ?? '');
  late bool _hidden = _existing?.hidden ?? false;
  bool _busy = false;

  static String _formatNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickPlant() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PlantPicker(),
    );
    if (id != null) setState(() => _plantId = id);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_plantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('plantRequired'))));
      return;
    }
    final mine = _app.backend.listings.where((l) => l.nurseryId == _app.user!.partnerId);
    if (_existing == null && mine.any((l) => l.plantId == _plantId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('alreadyListed'))));
      return;
    }
    setState(() => _busy = true);
    final price = double.parse(_price.text);
    final qty = int.parse(_quantity.text);
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.tr('saved');
    if (_existing == null) {
      final l = await _app.backend.addListing(plantId: _plantId!, price: price, quantity: qty);
      if (_hidden) await _app.backend.updateListing(l.copyWith(hidden: true));
    } else {
      await _app.backend.updateListing(_existing.copyWith(price: price, quantity: qty, hidden: _hidden));
    }
    messenger.showSnackBar(SnackBar(content: Text(saved)));
    if (mounted) context.go('/nursery');
  }

  @override
  Widget build(BuildContext context) {
    final plant = _plantId == null ? null : _app.backend.plantById(_plantId!);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(_existing == null ? 'addListing' : 'editListing'))),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  key: const Key('pickPlant'),
                  enabled: _existing == null,
                  leading: plant == null ? const Icon(Icons.local_florist_outlined) : PlantAvatar(plant: plant, size: 40),
                  title: Text(plant?.name(context.lang) ?? context.tr('choosePlant')),
                  subtitle: plant == null ? null : Text(plant.scientificName),
                  trailing: _existing == null ? const Icon(Icons.arrow_drop_down) : null,
                  onTap: _pickPlant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('priceField'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(labelText: context.tr('price')),
                validator: (v) {
                  final p = double.tryParse(v ?? '');
                  return p == null || p <= 0 ? context.tr('invalidPrice') : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('quantityField'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: context.tr('quantity')),
                validator: (v) => int.tryParse(v ?? '') == null ? context.tr('invalidQuantity') : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('hiddenSwitch'),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
                title: Text(context.tr('hideListing')),
              ),
              const SizedBox(height: 16),
              FilledButton(key: const Key('saveListing'), onPressed: _busy ? null : _save, child: Text(context.tr('save'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantPicker extends StatefulWidget {
  const _PlantPicker();

  @override
  State<_PlantPicker> createState() => _PlantPickerState();
}

class _PlantPickerState extends State<_PlantPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final plants = context
        .read<AppState>()
        .backend
        .plants
        .where((p) => matchesQuery(_query, [p.nameAr, p.nameEn, p.scientificName]))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('plantPickerSearch'),
              autofocus: true,
              decoration: InputDecoration(hintText: context.tr('choosePlant'), prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: plants.length,
              itemBuilder: (_, i) => ListTile(
                leading: PlantAvatar(plant: plants[i], size: 36),
                title: Text(plants[i].name(context.lang)),
                subtitle: Text(plants[i].scientificName),
                onTap: () => Navigator.pop(context, plants[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
