import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/watering.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_sheet.dart';
import '../widgets/common.dart';
import '../widgets/plant_photo.dart';

/// My Garden (US-21): one card per plant with its watering frequency from
/// the knowledge base and the next seven days drawn as a watering rhythm.
/// Plants due today are gathered at the top. A guest sees a sign-in prompt
/// (US-01 AC-02).
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    final market = app.backend;
    final now = DateTime.now();
    final items = [
      for (final g in market.garden)
        if (market.plantById(g.plantId) case final plant?) (garden: g, plant: plant, plan: WateringPlan.of(g, plant, now)),
    ]..sort((a, b) => a.plan.dueInDays.compareTo(b.plan.dueInDays)); // thirstiest first
    final due = items.where((i) => i.plan.isDue).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('myGarden')),
        actions: [
          if (user != null)
            IconButton(
              key: const Key('findProfessionals'),
              tooltip: context.tr('findProfessionals'),
              icon: const Icon(Icons.handyman_outlined),
              onPressed: () => context.go('/garden/care'),
            ),
          if (user != null && items.isNotEmpty)
            IconButton(
              key: const Key('addManually'),
              tooltip: context.tr('addManually'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.go('/garden/add'),
            ),
          const LanguageButton(),
        ],
      ),
      body: user == null
          ? SignInPrompt(icon: Icons.yard_outlined, body: context.tr('guestGardenBody'), from: '/garden')
          : items.isEmpty
          ? EmptyState(
              icon: Icons.yard_outlined,
              title: '${context.tr('welcome')} ${user.name}. ${context.tr('gardenEmpty')}',
              body: context.tr('gardenEmptyBody'),
              actions: [
                FilledButton.icon(
                  key: const Key('gardenBuyPlants'),
                  style: FilledButton.styleFrom(minimumSize: const Size(240, 48)),
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(context.tr('buyPlants')),
                  onPressed: () => context.go('/shop'),
                ),
                OutlinedButton.icon(
                  key: const Key('addManually'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(240, 48)),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('addManually')),
                  onPressed: () => context.go('/garden/add'),
                ),
              ],
            )
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
                children: [
                  _TodayPanel(due: [for (final d in due) d.plant], total: items.length),
                  const SizedBox(height: MashtalSpace.lg),
                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = MashtalSpace.md;
                      final columns = c.maxWidth >= 560 ? 3 : 2;
                      final width = (c.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final i in items)
                            SizedBox(
                              width: width,
                              child: GardenCard(garden: i.garden, plant: i.plant, plan: i.plan),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

/// What needs water today, so the screen answers "what do I do now?" first.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.due, required this.total});
  final List<Plant> due;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    final title = due.isEmpty
        ? context.tr('nothingToWater')
        : due.length == 1
        ? context.tr('toWaterOne')
        : context.tr('toWaterMany').replaceAll('{n}', '${due.length}');
    return Container(
      key: const Key('todayPanel'),
      padding: const EdgeInsets.all(MashtalSpace.lg),
      decoration: BoxDecoration(color: MashtalColors.forest, borderRadius: BorderRadius.circular(MashtalSpace.cardRadius)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: MashtalColors.lime, shape: BoxShape.circle),
            child: Icon(due.isEmpty ? Icons.check : Icons.water_drop, color: MashtalColors.forest),
          ),
          const SizedBox(width: MashtalSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(color: MashtalColors.surface)),
                Text(
                  due.isEmpty ? context.tr('plantsInGarden').replaceAll('{n}', '$total') : due.map((p) => p.name(lang)).join('، '),
                  style: text.bodyMedium?.copyWith(color: MashtalColors.lime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One owned plant: photo, name, how often it is watered and the next seven
/// days as a rhythm of drops. The round drop records a watering.
class GardenCard extends StatelessWidget {
  const GardenCard({super.key, required this.garden, required this.plant, required this.plan});
  final GardenPlant garden;
  final Plant plant;
  final WateringPlan plan;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final late = plan.dueInDays < 0;
    return Material(
      key: Key('garden-${garden.id}'),
      color: MashtalColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
        side: const BorderSide(color: MashtalColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      // US-22: the card opens the plant's page with its history.
      child: InkWell(
        onTap: () => context.go('/garden/plant/${garden.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MashtalSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: PlantPhoto.fill(plant: plant, radius: MashtalSpace.radius),
                  ),
                  PositionedDirectional(
                    end: MashtalSpace.sm,
                    bottom: MashtalSpace.sm,
                    child: WaterDot(garden: garden, plant: plant, due: plan.isDue),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(MashtalSpace.xs, MashtalSpace.sm, MashtalSpace.xs, MashtalSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(garden.quantity > 1 ? '${plant.name(lang)} × ${garden.quantity}' : plant.name(lang), style: text.titleMedium, maxLines: 2),
                    const SizedBox(height: MashtalSpace.xs),
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined, size: 16, color: MashtalColors.leaf),
                        const SizedBox(width: MashtalSpace.xs),
                        Flexible(
                          child: Text(wateringEveryText(lang, plant.wateringEveryDays), key: Key('frequency-${garden.id}'), style: text.bodyMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: MashtalSpace.sm),
                    WaterRhythm(days: plan.nextDays()),
                    const SizedBox(height: MashtalSpace.xs),
                    Text(
                      nextWateringText(lang, plan.dueInDays),
                      style: text.labelSmall?.copyWith(
                        color: late ? MashtalColors.error : (plan.isDue ? MashtalColors.forest : MashtalColors.muted),
                        fontWeight: plan.isDue ? FontWeight.w700 : null,
                      ),
                    ),
                    // US-23: care for this plant.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: Key('bookCare-${garden.id}'),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.xs)),
                        icon: const Icon(Icons.handyman_outlined, size: 18),
                        label: Text(context.tr('bookCare')),
                        onPressed: () => bookPlantCare(context, garden: garden, plantName: plant.name(lang)),
                      ),
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

/// Round button on the photo: "I watered it". Filled with the emerald blend
/// when the plant is due, plain white otherwise.
class WaterDot extends StatelessWidget {
  const WaterDot({super.key, required this.garden, required this.plant, required this.due});
  final GardenPlant garden;
  final Plant plant;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Tooltip(
      message: context.tr('iWatered'),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('water-${garden.id}'),
          customBorder: const CircleBorder(),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final msg = '${context.tr('wateredDone')} ${plant.name(context.lang)}';
            await app.backend.markWatered(garden.id);
            messenger.showSnackBar(SnackBar(content: Text(msg)));
          },
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: due ? MashtalColors.emeraldBlend : null,
              color: due ? null : MashtalColors.surface,
              boxShadow: const [BoxShadow(color: MashtalColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Icon(due ? Icons.water_drop : Icons.water_drop_outlined, color: due ? MashtalColors.forestDeep : MashtalColors.leaf, size: 22),
          ),
        ),
      ),
    );
  }
}

/// The next seven days, today first: a drop on each watering day.
class WaterRhythm extends StatelessWidget {
  const WaterRhythm({super.key, required this.days});
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final count = days.where((d) => d).length;
    return Semantics(
      label: context.tr('nextWeekRhythm').replaceAll('{n}', '$count'),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (final (i, water) in days.indexed) ...[
              if (i > 0) const Spacer(),
              SizedBox(
                width: 14,
                height: 18,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    water
                        ? const Icon(Icons.water_drop, size: 14, color: MashtalColors.leaf)
                        : Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: const BoxDecoration(color: MashtalColors.line, shape: BoxShape.circle),
                          ),
                    // Today is underlined.
                    Container(width: 10, height: 2, color: i == 0 ? MashtalColors.forest : Colors.transparent),
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
