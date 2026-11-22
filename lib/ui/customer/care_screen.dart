import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/professionals.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_sheet.dart';
import '../widgets/common.dart';

/// Plant care professionals (US-24): for the customer's city and a service
/// type, the verified professionals who cover both, with rating, jobs done and
/// the price range Mashtal set for that service.
class CareScreen extends StatelessWidget {
  const CareScreen({super.key, this.service, this.city, this.gardenPlantId});

  final ServiceType? service;

  /// Defaults to the customer's city.
  final String? city;

  /// The garden plant the care is for, when opened from a plant (US-23).
  final String? gardenPlantId;

  /// The care services first (as in the Book Plant Care sheet), then planting.
  static const services = [...careServices, ServiceType.planting];

  String _link({ServiceType? service, String? city}) => Uri(path: '/garden/care', queryParameters: {
        'service': (service ?? this.service ?? services.first).name,
        if ((city ?? this.city) != null) 'city': city ?? this.city!,
        'plant': ?gardenPlantId,
      }).toString();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final chosen = service ?? services.first;
    final where = city ?? app.user?.city ?? 'riyadh';
    final range = market.priceRanges.where((r) => r.service == chosen).firstOrNull;
    final pros = professionalsFor(market.professionals, city: where, service: chosen);
    final garden = gardenPlantId == null ? null : market.garden.where((g) => g.id == gardenPlantId).firstOrNull;
    final forPlant = garden == null ? null : market.plantById(garden.plantId);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(garden == null ? '/garden' : '/garden/plant/${garden.id}')),
        title: Text(context.tr('plantCare')),
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            if (forPlant != null)
              Padding(
                padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                child: Text('${context.tr('careFor')} ${forPlant.name(lang)}', style: text.bodyMedium),
              ),
            // Service type: one choice, like the Choose questions.
            Wrap(
              spacing: MashtalSpace.sm,
              runSpacing: MashtalSpace.sm,
              children: [
                for (final s in services)
                  ChoiceChip(
                    key: Key('service-${s.name}'),
                    label: Text(context.trEnum(s)),
                    selected: s == chosen,
                    onSelected: (_) => context.go(_link(service: s)),
                  ),
              ],
            ),
            const SizedBox(height: MashtalSpace.md),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: MashtalColors.leaf),
                const SizedBox(width: MashtalSpace.xs),
                Text(context.tr('inCity'), style: text.bodyMedium),
                const SizedBox(width: MashtalSpace.xs),
                DropdownButton<String>(
                  key: const Key('careCity'),
                  value: where,
                  underline: const SizedBox.shrink(),
                  style: text.titleSmall?.copyWith(color: MashtalColors.forest),
                  items: [for (final c in cityIds) DropdownMenuItem(value: c, child: Text(context.trCity(c)))],
                  onChanged: (c) => context.go(_link(city: c)),
                ),
              ],
            ),
            if (range != null) ...[
              const SizedBox(height: MashtalSpace.sm),
              PriceBand(service: chosen, range: range),
            ],
            const SizedBox(height: MashtalSpace.lg),
            if (pros.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MashtalSpace.xl),
                child: EmptyState(
                  key: const Key('noProfessionals'),
                  icon: Icons.engineering_outlined,
                  title: context.tr('noProsInArea'),
                  body: context.tr('noProsInAreaBody'),
                ),
              )
            else
              for (final p in pros)
                Padding(
                  padding: const EdgeInsets.only(bottom: MashtalSpace.md),
                  child: ProfessionalCard(professional: p, range: range, highlight: chosen),
                ),
          ],
        ),
      ),
    );
  }
}

/// The price range Mashtal set for a service, drawn as a band on a track so
/// it reads as "somewhere between", not one price.
class PriceBand extends StatelessWidget {
  const PriceBand({super.key, required this.service, required this.range});
  final ServiceType service;
  final PriceRange range;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('priceBand'),
      padding: const EdgeInsets.all(MashtalSpace.md),
      decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('priceSetBy').replaceAll('{service}', context.trEnum(service)), style: text.bodyMedium),
          const SizedBox(height: MashtalSpace.sm),
          Row(
            children: [
              Text(formatPrice(context, range.min), style: text.titleMedium),
              const SizedBox(width: MashtalSpace.sm),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(gradient: MashtalColors.emeraldBlend, borderRadius: BorderRadius.circular(MashtalSpace.pill)),
                ),
              ),
              const SizedBox(width: MashtalSpace.sm),
              Text(formatPrice(context, range.max), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: MashtalSpace.xs),
          Text(context.tr('priceAgreed'), style: text.bodySmall),
        ],
      ),
    );
  }
}

/// One professional: initial, name, rating and jobs done, what they offer
/// and where, and the price range for the chosen service.
class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({super.key, required this.professional, required this.range, required this.highlight});
  final Professional professional;
  final PriceRange? range;
  final ServiceType highlight;

  @override
  Widget build(BuildContext context) {
    final p = professional;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final name = p.name(lang);
    return Card(
      key: Key('pro-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(MashtalSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monogram instead of a stock avatar.
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: MashtalColors.forest, shape: BoxShape.circle),
              child: Text(name.characters.first, style: text.titleLarge?.copyWith(color: MashtalColors.lime)),
            ),
            const SizedBox(width: MashtalSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, style: text.titleMedium)),
                      const SizedBox(width: MashtalSpace.xs),
                      Tooltip(
                        message: context.tr('verifiedByMashtal'),
                        child: const Icon(Icons.verified_outlined, size: 18, color: MashtalColors.leaf),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      RatingLabel(rating: p.rating),
                      Text(' · ${p.jobsDone} ${context.tr('jobsDone')}', key: Key('jobs-${p.id}'), style: text.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: MashtalSpace.xs),
                  Text(
                    [for (final s in CareScreen.services) if (p.services.contains(s)) context.trEnum(s)].join(' · '),
                    style: text.bodySmall,
                  ),
                  if (range != null) ...[
                    const SizedBox(height: MashtalSpace.sm),
                    Text(
                      '${formatPrice(context, range!.min)} – ${formatPrice(context, range!.max)}',
                      key: Key('range-${p.id}'),
                      style: text.titleMedium?.copyWith(color: MashtalColors.forest),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
