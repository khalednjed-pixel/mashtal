import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

enum AdminTab { nurseries, professionals }

/// Admin onboarding and verification of partners (US-03).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.tab});
  final AdminTab tab;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final isNurseries = tab == AdminTab.nurseries;

    final rows = isNurseries
        ? [
            for (final n in market.nurseries)
              _PartnerRow(
                id: n.id,
                title: n.name(lang),
                subtitle: '${context.trCity(n.city)} · ${n.district} · ${n.phone}',
                status: n.status,
                onStatus: (s) => market.setNurseryStatus(n.id, s),
                onEdit: () => context.go('/admin/nurseries/edit/${n.id}'),
                onDelete: () => market.deleteNursery(n.id),
              ),
          ]
        : [
            for (final p in market.professionals)
              _PartnerRow(
                id: p.id,
                title: p.name(lang),
                subtitle: '${p.services.map(context.trEnum).join('، ')} · ${p.cities.map(context.trCity).join('، ')}',
                status: p.status,
                onStatus: (s) => market.setProfessionalStatus(p.id, s),
                onEdit: () => context.go('/admin/professionals/edit/${p.id}'),
                onDelete: () => market.deleteProfessional(p.id),
              ),
          ];
    // Pending first: that is the admin's to-do list.
    rows.sort((a, b) => a.status.index.compareTo(b.status.index));

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('admin')} · ${context.tr(isNurseries ? 'nurseries' : 'professionals')}'),
        actions: const [LanguageButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addPartner'),
        onPressed: () => context.go(isNurseries ? '/admin/nurseries/new' : '/admin/professionals/new'),
        icon: const Icon(Icons.add),
        label: Text(context.tr(isNurseries ? 'addNursery' : 'addProfessional')),
      ),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: r),
            if (!isNurseries) ...[
              const SizedBox(height: 16),
              Text(context.tr('priceRanges'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final r in market.priceRanges)
                      ListTile(
                        key: Key('range-${r.service.name}'),
                        dense: true,
                        title: Text(context.trEnum(r.service)),
                        subtitle: Text('${formatPrice(context, r.min)} – ${formatPrice(context, r.max)}'),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => showDialog<void>(context: context, builder: (_) => _PriceRangeDialog(range: r)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final String id;
  final String title;
  final String subtitle;
  final PartnerStatus status;
  final Future<void> Function(PartnerStatus) onStatus;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(key: Key('edit-$id'), tooltip: context.tr('edit'), icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
                    IconButton(
                      key: Key('delete-$id'),
                      tooltip: context.tr('delete'),
                      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                      onPressed: () async {
                        if (await confirmDelete(context, title)) await onDelete();
                      },
                    ),
                    if (status != PartnerStatus.verified)
                      FilledButton.tonalIcon(
                        key: Key('verify-$id'),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(context.tr('verify_action')),
                        onPressed: () => onStatus(PartnerStatus.verified),
                      ),
                    if (status == PartnerStatus.verified)
                      TextButton(
                        key: Key('suspend-$id'),
                        onPressed: () => onStatus(PartnerStatus.suspended),
                        child: Text(context.tr('suspend')),
                      ),
                    if (status == PartnerStatus.suspended)
                      TextButton(onPressed: () => onStatus(PartnerStatus.pending), child: Text(context.tr('setPending'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PriceRangeDialog extends StatefulWidget {
  const _PriceRangeDialog({required this.range});
  final PriceRange range;

  @override
  State<_PriceRangeDialog> createState() => _PriceRangeDialogState();
}

/// Admin edits the price range of one service type (feedback 7).
class _PriceRangeDialogState extends State<_PriceRangeDialog> {
  late final _min = TextEditingController(text: widget.range.min.toStringAsFixed(0));
  late final _max = TextEditingController(text: widget.range.max.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final min = double.tryParse(_min.text);
    final max = double.tryParse(_max.text);
    if (min == null || max == null || min <= 0 || min >= max) {
      setState(() => _error = context.tr('invalidRange'));
      return;
    }
    await context.read<AppState>().backend.updatePriceRange(widget.range.service, min: min, max: max);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${context.tr('editPriceRange')}: ${context.trEnum(widget.range.service)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const Key('rangeMin'), controller: _min, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: context.tr('min'))),
            const SizedBox(height: 12),
            TextField(key: const Key('rangeMax'), controller: _max, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: context.tr('max'))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          FilledButton(key: const Key('saveRange'), style: FilledButton.styleFrom(minimumSize: const Size(88, 40)), onPressed: _save, child: Text(context.tr('save'))),
        ],
      );
}
