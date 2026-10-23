import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';

/// A nursery adds a plant that is missing from the plant list. Pops with the
/// new plant's id so the listing form can select it.
class NewPlantScreen extends StatefulWidget {
  const NewPlantScreen({super.key});

  @override
  State<NewPlantScreen> createState() => _NewPlantScreenState();
}

class _NewPlantScreenState extends State<NewPlantScreen> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _scientific = TextEditingController();
  final _days = TextEditingController(text: '7');
  final _descAr = TextEditingController();
  final _descEn = TextEditingController();
  PlantCategory _category = PlantCategory.shrub;
  final Set<Placement> _placements = {Placement.outdoor};
  Sun _sun = Sun.full;
  Water _water = Water.medium;
  bool _toxic = false;
  String? _photo;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _scientific, _days, _descAr, _descEn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_placements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('placementRequired'))));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final full = context.tr('storageFull');
    try {
      final plant = await context.read<AppState>().backend.addPlant(Plant(
            id: '',
            nameAr: _nameAr.text,
            nameEn: _nameEn.text,
            scientificName: _scientific.text,
            category: _category,
            placements: {..._placements},
            sun: _sun,
            water: _water,
            wateringEveryDays: int.parse(_days.text),
            toxic: _toxic,
            descriptionAr: _descAr.text,
            descriptionEn: _descEn.text,
            source: '',
            guideBacked: false,
            photo: _photo,
          ));
      if (mounted) Navigator.of(context).pop(plant.id);
    } on StorageFull {
      messenger.showSnackBar(SnackBar(content: Text(full)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _nameCheck(String? _) =>
      _nameAr.text.trim().isEmpty && _nameEn.text.trim().isEmpty ? context.tr('nameOneRequired') : null;

  Widget _choices<T extends Enum>(String label, List<T> values, bool Function(T) selected, void Function(T) onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(label), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in values)
                FilterChip(
                  key: Key('$label-${v.name}'),
                  label: Text(context.trEnum(v)),
                  selected: selected(v),
                  onSelected: (_) => setState(() => onTap(v)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('newPlant'))),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(padding: const EdgeInsets.all(12), child: Text(context.tr('newPlantNote'))),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('newPlantNameAr'),
                controller: _nameAr,
                decoration: InputDecoration(labelText: context.tr('nameAr')),
                validator: _nameCheck,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('newPlantNameEn'),
                controller: _nameEn,
                decoration: InputDecoration(labelText: context.tr('nameEn')),
                validator: _nameCheck,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _scientific, decoration: InputDecoration(labelText: context.tr('scientificName'))),
              _choices('category', PlantCategory.values, (v) => v == _category, (v) => _category = v),
              _choices('placement', Placement.values, _placements.contains,
                  (v) => _placements.contains(v) ? _placements.remove(v) : _placements.add(v)),
              _choices('sun', Sun.values, (v) => v == _sun, (v) => _sun = v),
              _choices('water', Water.values, (v) => v == _water, (v) => _water = v),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('newPlantDays'),
                controller: _days,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: InputDecoration(labelText: context.tr('wateringDays')),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? context.tr('invalidQuantity') : null,
              ),
              SwitchListTile(
                value: _toxic,
                onChanged: (v) => setState(() => _toxic = v),
                title: Text(context.tr('toxicSwitch')),
              ),
              TextFormField(
                controller: _descAr,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(labelText: context.tr('descriptionAr')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descEn,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(labelText: context.tr('descriptionEn')),
              ),
              const SizedBox(height: 12),
              Text(context.tr('photo'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              PhotoField(photo: _photo, onChanged: (p) => setState(() => _photo = p)),
              const SizedBox(height: 16),
              FilledButton(key: const Key('saveNewPlant'), onPressed: _busy ? null : _save, child: Text(context.tr('save'))),
            ],
          ),
        ),
      ),
    );
  }
}
