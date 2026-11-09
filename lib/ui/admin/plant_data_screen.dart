import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/text_match.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/not_found.dart';
import '../widgets/plant_photo.dart';

/// Admin list of the plant knowledge base (US-14).
class PlantDataScreen extends StatefulWidget {
  const PlantDataScreen({super.key});

  @override
  State<PlantDataScreen> createState() => _PlantDataScreenState();
}

class _PlantDataScreenState extends State<PlantDataScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<AppState>().backend;
    final lang = context.lang;
    final plants = market.plants.where((p) => matchesQuery(_query.text, [p.nameAr, p.nameEn, p.scientificName])).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('admin')} · ${context.tr('plantData')}'),
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.all(16)),
          children: [
            Text(context.tr('plantDataHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              key: const Key('plantDataSearch'),
              controller: _query,
              decoration: InputDecoration(hintText: context.tr('searchHint'), prefixIcon: const Icon(Icons.search)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            for (final p in plants)
              Card(
                child: ListTile(
                  key: Key('plantData-${p.id}'),
                  leading: PlantPhoto(plant: p, size: 44),
                  title: Text(p.name(lang)),
                  subtitle: Text(
                    '${context.trEnum(p.sun)} · ${context.tr('water')}: ${context.trEnum(p.water)} · '
                    '${context.tr('waterEvery')} ${p.wateringEveryDays} ${context.tr('days')}${p.toxic ? ' · ⚠' : ''}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => context.go('/admin/plants/edit/${p.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Edit form for one plant with its edit history (US-14 AC-01, AC-02).
class PlantEditScreen extends StatefulWidget {
  const PlantEditScreen({super.key, required this.plantId});
  final String plantId;

  @override
  State<PlantEditScreen> createState() => _PlantEditScreenState();
}

class _PlantEditScreenState extends State<PlantEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Plant? _original = context.read<AppState>().backend.plantById(widget.plantId);
  late final Set<Placement> _placements = {...?_original?.placements};
  late Sun _sun = _original?.sun ?? Sun.full;
  late Water _water = _original?.water ?? Water.low;
  late bool _toxic = _original?.toxic ?? false;
  late final _days = TextEditingController(text: '${_original?.wateringEveryDays ?? 7}');
  bool _saving = false;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_placements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('placementRequired'))));
      return;
    }
    setState(() => _saving = true);
    final market = context.read<AppState>().backend;
    await market.updatePlant(_original!.copyWith(
      placements: _placements,
      sun: _sun,
      water: _water,
      wateringEveryDays: int.parse(_days.text),
      toxic: _toxic,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final plant = _original;
    if (plant == null) return const NotFoundScreen();
    final market = context.watch<AppState>().backend;
    final history = market.plantEditsFor(plant.id);
    final theme = Theme.of(context);
    final when = DateFormat('yyyy-MM-dd HH:mm');

    Widget chips<T extends Enum>(String title, List<T> values, bool Function(T) selected, void Function(T) onTap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(title, style: theme.textTheme.titleSmall)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final v in values)
                  FilterChip(key: Key('chip-${v.name}'), label: Text(context.trEnum(v)), selected: selected(v), onSelected: (_) => onTap(v)),
              ],
            ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('editPlant')}: ${plant.name(context.lang)}'), actions: const [LanguageButton()]),
      body: Constrained(
        child: Form(
          key: _form,
          child: ListView(
            padding: clearNav(context, const EdgeInsets.all(16)),
            children: [
              Text(context.tr('plantDataHint'), style: theme.textTheme.bodySmall),
              chips<Placement>(context.tr('placement'), Placement.values, _placements.contains, (v) {
                setState(() => _placements.contains(v) ? _placements.remove(v) : _placements.add(v));
              }),
              chips<Sun>(context.tr('sun'), Sun.values, (v) => v == _sun, (v) => setState(() => _sun = v)),
              chips<Water>(context.tr('water'), Water.values, (v) => v == _water, (v) => setState(() => _water = v)),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('daysField'),
                controller: _days,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: context.tr('wateringDays')),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 60 ? context.tr('invalidDays') : null;
                },
              ),
              SwitchListTile(
                key: const Key('toxicSwitch'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('toxicSwitch')),
                value: _toxic,
                onChanged: (v) => setState(() => _toxic = v),
              ),
              const SizedBox(height: 8),
              FilledButton(key: const Key('savePlant'), onPressed: _saving ? null : _save, child: Text(context.tr('save'))),
              const SizedBox(height: 24),
              Text(context.tr('editHistory'), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              if (history.isEmpty) Text(context.tr('noEdits'), style: theme.textTheme.bodySmall),
              for (final e in history)
                ListTile(
                  key: Key('edit-${e.field}-${e.at.microsecondsSinceEpoch}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text('${context.tr('field.${e.field}')}: ${editValue(context, e.field, e.oldValue)} → ${editValue(context, e.field, e.newValue)}'),
                  subtitle: Text('${e.editorName} · ${when.format(e.at)}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A logged value in the current language: the log stores enum names and
/// true/false so it stays language-neutral.
String editValue(BuildContext context, String field, String raw) {
  T? byName<T extends Enum>(List<T> values, String name) => values.where((v) => v.name == name).firstOrNull;
  String en(Enum? v) => v == null ? raw : context.trEnum(v);
  return switch (field) {
    'placements' => raw.isEmpty ? raw : raw.split(', ').map((n) => en(byName(Placement.values, n))).join(context.lang == 'ar' ? '، ' : ', '),
    'sun' => en(byName(Sun.values, raw)),
    'water' => en(byName(Water.values, raw)),
    'toxic' => context.tr(raw == 'true' ? 'yes' : 'no'),
    _ => raw,
  };
}
