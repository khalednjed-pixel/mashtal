import 'package:flutter/material.dart';
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
                        dense: true,
                        title: Text(context.trEnum(r.service)),
                        trailing: Text('${formatPrice(context, r.min)} – ${formatPrice(context, r.max)}'),
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
  const _PartnerRow({required this.id, required this.title, required this.subtitle, required this.status, required this.onStatus});

  final String id;
  final String title;
  final String subtitle;
  final PartnerStatus status;
  final Future<void> Function(PartnerStatus) onStatus;

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
                  children: [
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
