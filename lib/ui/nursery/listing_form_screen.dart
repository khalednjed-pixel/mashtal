import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories.dart';
import '../../l10n/strings.dart';
import '../../logic/text_match.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';
import '../widgets/plant_photo.dart';
import 'new_plant_screen.dart';

/// Add, edit or delete a listing. The plant comes from the plant list, so
/// every listing links to its plant record (US-06 AC-01). A nursery can add a
/// plant that is missing from the list, and its own photo.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  /// Null when adding a new listing.
  final String? listingId;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  late final AppState _app = Provider.of<AppState>(context, listen: false);
  late final Listing? _existing =
      widget.listingId == null ? null : _app.backend.listings.where((l) => l.id == widget.listingId).firstOrNull;

  late String? _plantId = _existing?.plantId;
  late final _price = TextEditingController(text: _existing == null ? '' : _formatNumber(_existing.price));
  late final _quantity = TextEditingController(text: _existing?.quantity.toString() ?? '');
  late bool _hidden = _existing?.hidden ?? false;
  late String? _photo = _existing?.photo;
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
      builder: (_) => ChangeNotifierProvider.value(value: _app, child: const _PlantPicker()),
    );
    if (id == null || !mounted) return;
    if (id == _PlantPicker.addNew) {
      // Pushed on the navigator rather than as a route, so the router refresh
      // that follows the new plant being saved does not keep the page open.
      final created = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const NewPlantScreen()));
      if (created != null) setState(() => _plantId = created);
    } else {
      setState(() => _plantId = id);
    }
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
    final full = context.tr('storageFull');
    try {
      if (_existing == null) {
        final l = await _app.backend.addListing(plantId: _plantId!, price: price, quantity: qty, photo: _photo);
        if (_hidden) await _app.backend.updateListing(l.copyWith(hidden: true));
      } else {
        await _app.backend.updateListing(_existing.copyWith(price: price, quantity: qty, hidden: _hidden, photo: () => _photo));
      }
      messenger.showSnackBar(SnackBar(content: Text(saved)));
      if (mounted) context.go('/nursery');
    } on StorageFull {
      messenger.showSnackBar(SnackBar(content: Text(full)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final plant = _app.backend.plantById(_existing!.plantId);
    if (!await confirmDelete(context, plant?.name(context.lang) ?? '')) return;
    await _app.backend.deleteListing(_existing.id);
    if (mounted) context.go('/nursery');
  }

  @override
  Widget build(BuildContext context) {
    final plant = _plantId == null ? null : _app.backend.plantById(_plantId!);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_existing == null ? 'addListing' : 'editListing')),
        actions: [
          if (_existing != null)
            IconButton(
              key: const Key('deleteListing'),
              tooltip: context.tr('deleteListing'),
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              onPressed: _delete,
            ),
        ],
      ),
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
                  leading: plant == null ? const Icon(Icons.local_florist_outlined) : PlantPhoto(plant: plant, size: 40),
                  title: Text(plant?.name(context.lang) ?? context.tr('choosePlant')),
                  subtitle: plant == null ? null : Text(plant.isCustom ? context.tr('addedByNursery') : plant.scientificName),
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
              const SizedBox(height: 16),
              Text(context.tr('nurseryPhoto'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              PhotoField(photo: _photo, onChanged: (p) => setState(() => _photo = p)),
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

  /// Returned when the nursery wants to add a plant that is not in the list.
  static const addNew = '__new__';

  @override
  State<_PlantPicker> createState() => _PlantPickerState();
}

class _PlantPickerState extends State<_PlantPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final myNursery = app.user?.partnerId;
    final plants = app.backend.plants.where((p) => matchesQuery(_query, [p.nameAr, p.nameEn, p.scientificName])).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
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
          ListTile(
            key: const Key('addNewPlant'),
            leading: const Icon(Icons.add_circle_outline),
            title: Text(context.tr('addNewPlant'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () => Navigator.pop(context, _PlantPicker.addNew),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: plants.length,
              itemBuilder: (_, i) {
                final p = plants[i];
                final mine = p.isCustom && p.addedBy == myNursery;
                return ListTile(
                  leading: PlantPhoto(plant: p, size: 36),
                  title: Text(p.name(context.lang)),
                  subtitle: Text(p.isCustom ? context.tr('addedByNursery') : p.scientificName),
                  // A nursery can delete the plants it added itself.
                  trailing: mine
                      ? IconButton(
                          key: Key('deletePlant-${p.id}'),
                          tooltip: context.tr('deletePlant'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirmDelete(context, p.name(context.lang))) await app.backend.deletePlant(p.id);
                          },
                        )
                      : null,
                  onTap: () => Navigator.pop(context, p.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
