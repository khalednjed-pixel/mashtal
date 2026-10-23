import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Professional profile: status, rating, the services offered with the
/// admin's price range for each, and the cities covered. Booking requests
/// arrive in Sprint 4.
class ProHomeScreen extends StatefulWidget {
  const ProHomeScreen({super.key});

  @override
  State<ProHomeScreen> createState() => _ProHomeScreenState();
}

class _ProHomeScreenState extends State<ProHomeScreen> {
  Set<ServiceType>? _services;
  Set<String>? _cities;
  bool _busy = false;

  Future<void> _save(AppState app, Professional pro) async {
    if (_services!.isEmpty || _cities!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('chooseOne'))));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.tr('saved');
    await app.backend.updateProfessional(pro.copyWith(
      services: {..._services!},
      cities: [for (final c in cityIds) if (_cities!.contains(c)) c],
    ));
    messenger.showSnackBar(SnackBar(content: Text(saved)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pro = app.backend.professionals.where((p) => p.id == app.user?.partnerId).firstOrNull;
    final theme = Theme.of(context);
    final lang = context.lang;
    if (pro == null) return const SizedBox.shrink();
    final services = _services ??= {...pro.services};
    final cities = _cities ??= {...pro.cities};
    final changed = services.length != pro.services.length ||
        !services.containsAll(pro.services) ||
        cities.length != pro.cities.length ||
        !cities.containsAll(pro.cities);
    final ranges = {for (final r in app.backend.priceRanges) r.service: r};

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('myProfile')), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pro.status != PartnerStatus.verified)
              Card(
                key: const Key('proStatusBanner'),
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top),
                  title: Text(pro.status == PartnerStatus.pending ? context.tr('pendingPro') : context.trEnum(pro.status)),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(child: Text(pro.name(lang).characters.first)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(pro.name(lang), style: theme.textTheme.titleLarge)),
                      StatusChip(status: pro.status),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      RatingLabel(rating: pro.rating),
                      const SizedBox(width: 16),
                      Text('${pro.jobsDone} ${context.tr('jobsDone')}'),
                    ]),
                    const SizedBox(height: 4),
                    Text(pro.phone, textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(context.tr('myServices'), style: theme.textTheme.titleMedium),
            Card(
              child: Column(
                children: [
                  for (final s in ServiceType.values)
                    CheckboxListTile(
                      key: Key('service-${s.name}'),
                      value: services.contains(s),
                      onChanged: (v) => setState(() => v! ? services.add(s) : services.remove(s)),
                      title: Text(context.trEnum(s)),
                      subtitle: ranges[s] == null
                          ? null
                          : Text('${formatPrice(context, ranges[s]!.min)} – ${formatPrice(context, ranges[s]!.max)}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(context.tr('coverage'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in cityIds)
                  FilterChip(
                    key: Key('cover-$c'),
                    label: Text(context.trCity(c)),
                    selected: cities.contains(c),
                    onSelected: (v) => setState(() => v ? cities.add(c) : cities.remove(c)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('saveProProfile'),
              onPressed: !changed || _busy ? null : () => _save(app, pro),
              child: Text(context.tr('save')),
            ),
            const SizedBox(height: 24),
            Text(context.tr('jobs'), style: theme.textTheme.titleMedium),
            EmptyState(icon: Icons.handyman_outlined, title: context.tr('jobsSoon')),
          ],
        ),
      ),
    );
  }
}
