import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/local_backend.dart';
import '../../l10n/strings.dart';
import '../../logic/care_tips.dart';
import '../../logic/history.dart';
import '../../logic/watering.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_sheet.dart';
import '../widgets/common.dart';
import '../widgets/not_found.dart';
import '../widgets/plant_photo.dart';
import 'garden_screen.dart' show WaterRhythm;

/// One plant in My Garden: its watering rhythm and its history (US-22), a
/// timeline growing down a stem, newest first, each entry with its date and
/// where it came from.
class GardenPlantScreen extends StatelessWidget {
  const GardenPlantScreen({super.key, required this.gardenPlantId});
  final String gardenPlantId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final g = market.garden.where((g) => g.id == gardenPlantId).firstOrNull;
    final plant = g == null ? null : market.plantById(g.plantId);
    if (g == null || plant == null) return const NotFoundScreen();

    final plan = WateringPlan.of(g, plant, DateTime.now());
    final story = plantStory(
      g,
      market.historyOf(g.id),
      nursery: g.nurseryId == null ? null : market.nurseryById(g.nurseryId!),
      lang: lang,
    );
    final title = g.quantity > 1 ? '${plant.name(lang)} × ${g.quantity}' : plant.name(lang);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/garden')),
        title: Text(title),
        actions: [
          const LanguageButton(),
          // A plain button: a popup menu inside the app's SelectionArea trips
          // a Flutter layout assertion.
          IconButton(
            key: const Key('removeFromGarden'),
            tooltip: context.tr('removeFromGarden'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _remove(context, app, g, plant.name(lang)),
          ),
        ],
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
              child: AspectRatio(aspectRatio: 4 / 3, child: PlantPhoto.fill(plant: plant)),
            ),
            const SizedBox(height: MashtalSpace.md),
            // Latin name: LTR, but on the reading side of the screen.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                plant.scientificName,
                textDirection: TextDirection.ltr,
                style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontSize: 13, color: MashtalColors.muted),
              ),
            ),
            const SizedBox(height: MashtalSpace.md),
            // Watering: how often, the coming week, and the screen's one action.
            Container(
              padding: const EdgeInsets.all(MashtalSpace.lg),
              decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop_outlined, color: MashtalColors.leaf),
                      const SizedBox(width: MashtalSpace.sm),
                      Text(wateringEveryText(lang, plant.wateringEveryDays), style: text.titleMedium),
                      const Spacer(),
                      Text(nextWateringText(lang, plan.dueInDays), style: text.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: MashtalSpace.md),
                  WaterRhythm(days: plan.nextDays()),
                  const SizedBox(height: MashtalSpace.lg),
                  FilledButton.icon(
                    key: const Key('waterNow'),
                    icon: const Icon(Icons.water_drop),
                    label: Text(context.tr('iWatered')),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final msg = '${context.tr('wateredDone')} ${plant.name(lang)}';
                      await market.markWatered(g.id);
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: MashtalSpace.md),
            // US-23: the second action, outlined; watering stays the primary one.
            OutlinedButton.icon(
              key: const Key('bookCare'),
              icon: const Icon(Icons.handyman_outlined),
              label: Text(context.tr('bookCare')),
              onPressed: () => bookPlantCare(context, garden: g, plantName: plant.name(lang)),
            ),
            const SizedBox(height: MashtalSpace.xl),
            _CareTips(plant: plant),
            const SizedBox(height: MashtalSpace.xl),
            Row(
              children: [
                Expanded(child: Text(context.tr('plantStory'), style: text.titleLarge)),
                TextButton.icon(
                  key: const Key('addNote'),
                  icon: const Icon(Icons.edit_note),
                  label: Text(context.tr('addNote')),
                  onPressed: () => _addNote(context, market, g.id),
                ),
              ],
            ),
            const SizedBox(height: MashtalSpace.sm),
            for (final (i, item) in story.indexed) _StoryEntry(item: item, last: i == story.length - 1),
            if (!story.any((i) => i.kind == HistoryKind.check || i.kind == HistoryKind.proFeedback))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: MashtalSpace.sm),
                child: Text(context.tr('historyLater'), style: text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, LocalBackend market, String id) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('addNote')),
        content: TextField(
          key: const Key('noteField'),
          controller: controller,
          autofocus: true,
          maxLength: LocalBackend.noteMaxLength,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(hintText: c.tr('noteHint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('cancel'))),
          FilledButton(
            key: const Key('saveNote'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(c.tr('save')),
          ),
        ],
      ),
    );
    if (note != null && note.trim().isNotEmpty) await market.addNote(id, note);
  }

  Future<void> _remove(BuildContext context, AppState app, GardenPlant g, String name) async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('removeFromGarden')),
        content: Text(c.tr('removeFromGardenBody').replaceAll('{item}', name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
          FilledButton(
            key: const Key('confirmRemoveFromGarden'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.backend.removeFromGarden(g.id);
    router.go('/garden');
  }
}

/// General care tips for this plant, as one calm panel of rows. They come
/// from the plant's needs, not from a guide, and the caption says so.
class _CareTips extends StatelessWidget {
  const _CareTips({required this.plant});
  final Plant plant;

  static IconData _icon(TipTopic t) => switch (t) {
        TipTopic.light => Icons.wb_sunny_outlined,
        TipTopic.water => Icons.water_drop_outlined,
        TipTopic.heat => Icons.thermostat_outlined,
        TipTopic.indoor => Icons.ac_unit,
        TipTopic.soil => Icons.grass_outlined,
        TipTopic.safety => Icons.child_care_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tips = careTipsFor(plant);
    return Column(
      key: const Key('careTips'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('careTips'), style: text.titleLarge),
        const SizedBox(height: MashtalSpace.xs),
        Text(context.tr('careTipsNote'), style: text.bodySmall),
        const SizedBox(height: MashtalSpace.md),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: MashtalColors.line), borderRadius: BorderRadius.circular(MashtalSpace.radius)),
          child: Column(
            children: [
              for (final (i, tip) in tips.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: MashtalSpace.lg, endIndent: MashtalSpace.lg),
                Padding(
                  key: Key('tip-${tip.topic.name}'),
                  padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.lg, vertical: MashtalSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(tip.topic), size: 20, color: tip.topic == TipTopic.safety ? MashtalColors.error : MashtalColors.leaf),
                      const SizedBox(width: MashtalSpace.md),
                      Expanded(child: Text(context.tr(tip.key), style: text.bodyMedium)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One entry on the history stem: a leaf node with the kind's icon, then
/// what happened, when and from whom.
class _StoryEntry extends StatelessWidget {
  const _StoryEntry({required this.item, required this.last});
  final HistoryItem item;
  final bool last;

  static IconData _icon(HistoryKind k) => switch (k) {
        HistoryKind.added => Icons.add_circle_outline,
        HistoryKind.pickedUp => Icons.storefront_outlined,
        HistoryKind.watered => Icons.water_drop_outlined,
        HistoryKind.note => Icons.edit_note,
        HistoryKind.check => Icons.photo_camera_outlined,
        HistoryKind.proFeedback => Icons.handyman_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    final date = DateFormat('d MMMM y', lang).format(item.at.toLocal());
    final source = item.sourceName ?? context.tr('src.${item.source.name}');
    final strong = item.kind == HistoryKind.check || item.kind == HistoryKind.proFeedback;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: strong ? MashtalColors.forest : MashtalColors.mint, shape: BoxShape.circle),
                  child: Icon(_icon(item.kind), size: 20, color: strong ? MashtalColors.lime : MashtalColors.forest),
                ),
                if (!last) Expanded(child: Container(width: 2, color: MashtalColors.mint)),
              ],
            ),
          ),
          const SizedBox(width: MashtalSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: MashtalSpace.lg, top: MashtalSpace.xs),
              child: Column(
                key: Key('story-${item.kind.name}-${item.at.microsecondsSinceEpoch}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('h.${item.kind.name}'), style: text.titleMedium),
                  Text('$source · $date', style: text.bodySmall),
                  if (item.text != null) ...[
                    const SizedBox(height: MashtalSpace.xs),
                    Text(item.text!, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
