import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/local_backend.dart';
import '../../l10n/strings.dart';
import '../../logic/care_plan.dart';
import '../../logic/care_tips.dart';
import '../../logic/history.dart';
import '../../logic/reminders.dart';
import '../../logic/watering.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_sheet.dart';
import '../widgets/common.dart';
import '../widgets/garden_art.dart';
import '../widgets/home_picker.dart';
import '../widgets/not_found.dart';
import '../widgets/photo_picker.dart' show choosePhoto;
import '../widgets/pickup_pass.dart' show openExternal;
import '../widgets/plant_photo.dart';
import '../widgets/water_ring.dart';
import 'garden_screen.dart' show WaterRhythm, planEveryText, planReasonsText;

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

    final plan = CarePlan.of(g, plant, DateTime.now());
    final story = plantStory(g, market.historyOf(g.id), nursery: g.nurseryId == null ? null : market.nurseryById(g.nurseryId!), lang: lang);
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
            // A small round portrait, so the watering ring fits on the first
            // screen of a phone.
            Row(
              children: [
                PlantPhoto(plant: plant, size: 64, radius: 32),
                const SizedBox(width: MashtalSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Latin name: LTR, but on the reading side of the screen.
                      Text(
                        plant.scientificName,
                        textDirection: TextDirection.ltr,
                        style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontSize: 13, color: MashtalColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text('${context.tr('inGardenSince')} ${DateFormat('d MMMM y', lang).format(g.addedAt.toLocal())}', style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MashtalSpace.lg),
            // Watering: the ring is the screen's one action. Press and hold
            // to water; under it, why the plan is what it is.
            Center(
              child: WaterRing(
                plan: plan,
                onWatered: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final msg = '${context.tr('wateredDone')} ${plant.name(lang)}';
                  await market.markWatered(g.id);
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
            ),
            const SizedBox(height: MashtalSpace.md),
            Material(
              color: MashtalColors.waterSoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
              child: Padding(
                padding: const EdgeInsets.all(MashtalSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined, color: MashtalColors.water),
                        const SizedBox(width: MashtalSpace.sm),
                        Expanded(
                          child: Text(planEveryText(context, plan), key: const Key('planEvery'), style: text.titleMedium),
                        ),
                        Text(nextWateringText(lang, plan.dueInDays), style: text.bodyMedium),
                      ],
                    ),
                    if (plan.reasons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 32, top: 2),
                        child: Text(planReasonsText(context, plan), key: const Key('planReasons'), style: text.bodySmall),
                      ),
                    const SizedBox(height: MashtalSpace.md),
                    WaterRhythm(days: plan.nextDays()),
                    const SizedBox(height: MashtalSpace.md),
                    // Where it lives: one tap to change; the guess is said out loud.
                    Row(
                      children: [
                        GardenArt(homeArt(plan.home), size: 32),
                        const SizedBox(width: MashtalSpace.sm),
                        Expanded(
                          child: Text(
                            '${context.tr('livesIn')}: ${context.tr('home.${plan.home.name}')}${plan.homeGuessed ? ' (${context.tr('ourGuess')})' : ''}',
                            style: text.bodyMedium,
                          ),
                        ),
                        TextButton(
                          key: const Key('changeHome'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final failed = context.tr('saveFailed');
                            final h = await pickHome(context, current: plan.home, guessed: plan.homeGuessed);
                            if (h == null) return;
                            try {
                              await market.setHome(g.id, h);
                            } catch (e) {
                              debugPrint('setHome failed: $e');
                              messenger.showSnackBar(SnackBar(content: Text(failed)));
                            }
                          },
                          child: Text(context.tr('change')),
                        ),
                      ],
                    ),
                    if (plan.isDue) ...[
                      const SizedBox(height: MashtalSpace.xs),
                      OutlinedButton.icon(
                        key: const Key('stillMoist'),
                        icon: const Icon(Icons.back_hand_outlined),
                        label: Text(context.tr('stillMoist')),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final msg = context.tr('stillMoistDone');
                          await market.markStillMoist(g.id);
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        },
                      ),
                    ],
                    // Reminders that arrive with the app closed: the phone's calendar.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('calendarReminder'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: MashtalColors.leaf),
                        icon: const Icon(Icons.event_repeat_outlined),
                        label: Text(context.tr('remindMe')),
                        onPressed: () => openExternal(
                          calendarReminder(
                            title: context.tr('reminderTitle').replaceAll('{plant}', plant.name(lang)),
                            details: context.tr('reminderDetails'),
                            firstDay: DateTime.now().add(Duration(days: plan.dueInDays < 0 ? 0 : plan.dueInDays)),
                            everyDays: plan.everyDays,
                          ),
                        ),
                      ),
                    ),
                    // How to tell, for someone who has never checked soil.
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const Key('howToCheck'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                        leading: const Icon(Icons.help_outline, color: MashtalColors.leaf),
                        title: Text(context.tr('howToCheck'), style: text.bodyMedium?.copyWith(color: MashtalColors.leaf)),
                        children: [Text(context.tr('howToCheckBody'), style: text.bodyMedium)],
                      ),
                    ),
                  ],
                ),
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
            _GrowthPhotos(
              garden: g,
              photos: [
                for (final e in market.historyOf(g.id))
                  if (e.kind == HistoryKind.photo && e.photo != null) e,
              ],
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

/// Growth photos: a strip that starts with "add photo", newest first, and
/// once there are two, the first and the latest side by side.
class _GrowthPhotos extends StatelessWidget {
  const _GrowthPhotos({required this.garden, required this.photos});
  final GardenPlant garden;

  /// Newest first.
  final List<HistoryEntry> photos;

  Future<void> _add(BuildContext context) async {
    final market = context.read<AppState>().backend;
    final messenger = ScaffoldMessenger.of(context);
    final done = context.tr('photoAdded');
    final photo = await choosePhoto(context);
    if (photo == null) return;
    await market.addGrowthPhoto(garden.id, photo);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  void _open(BuildContext context, HistoryEntry e) {
    final date = DateFormat('d MMMM y', context.lang).format(e.at.toLocal());
    showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.cardRadius)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.memory(decodePhoto(e.photo!), fit: BoxFit.contain)),
            Padding(
              padding: const EdgeInsets.all(MashtalSpace.md),
              child: Text(date, style: Theme.of(c).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    String day(DateTime t) => DateFormat('d MMM', lang).format(t.toLocal());
    return Column(
      key: const Key('growthPhotos'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('growthPhotos'), style: text.titleLarge),
        const SizedBox(height: MashtalSpace.xs),
        Text(context.tr('growthPhotosBody'), style: text.bodySmall),
        const SizedBox(height: MashtalSpace.md),
        if (photos.length >= 2) ...[
          _ThenAndNow(first: photos.last, latest: photos.first, onOpen: (e) => _open(context, e)),
          const SizedBox(height: MashtalSpace.md),
        ],
        SizedBox(
          height: 132,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // The first tile adds a photo: a soft framed tile with a camera.
              Align(
                alignment: AlignmentDirectional.topStart,
                child: InkWell(
                  key: const Key('addGrowthPhoto'),
                  borderRadius: BorderRadius.circular(MashtalSpace.radius),
                  onTap: () => _add(context),
                  child: Container(
                    width: 104,
                    height: 104,
                    margin: const EdgeInsetsDirectional.only(end: MashtalSpace.sm),
                    decoration: BoxDecoration(
                      color: MashtalColors.ground,
                      borderRadius: BorderRadius.circular(MashtalSpace.radius),
                      border: Border.all(color: MashtalColors.leaf, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: MashtalColors.leaf, size: 28),
                        const SizedBox(height: MashtalSpace.xs),
                        Text(context.tr('addGrowthPhoto'), style: text.labelLarge?.copyWith(color: MashtalColors.leaf)),
                      ],
                    ),
                  ),
                ),
              ),
              for (final e in photos)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: MashtalSpace.sm),
                  child: InkWell(
                    key: Key('growth-${e.id}'),
                    borderRadius: BorderRadius.circular(MashtalSpace.radius),
                    onTap: () => _open(context, e),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MashtalSpace.radius),
                          child: Image.memory(decodePhoto(e.photo!), width: 104, height: 104, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: MashtalSpace.xs),
                        Text(day(e.at), style: text.bodySmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The first photo and the latest, side by side, with how far apart they are.
class _ThenAndNow extends StatelessWidget {
  const _ThenAndNow({required this.first, required this.latest, required this.onOpen});
  final HistoryEntry first;
  final HistoryEntry latest;
  final ValueChanged<HistoryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    final days = latest.at.difference(first.at).inDays;
    Widget side(HistoryEntry e, String label) => Expanded(
      child: GestureDetector(
        onTap: () => onOpen(e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MashtalSpace.radius),
                child: Image.memory(decodePhoto(e.photo!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: MashtalSpace.xs),
            Text(label, style: text.titleSmall),
            Text(DateFormat('d MMMM y', lang).format(e.at.toLocal()), style: text.bodySmall),
          ],
        ),
      ),
    );
    return Container(
      key: const Key('thenAndNow'),
      padding: const EdgeInsets.all(MashtalSpace.md),
      decoration: BoxDecoration(
        color: MashtalColors.surface,
        borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
        border: Border.all(color: MashtalColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('thenAndNow'), style: text.titleMedium)),
              if (days > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.xs),
                  decoration: BoxDecoration(color: MashtalColors.mint, borderRadius: BorderRadius.circular(MashtalSpace.pill)),
                  child: Text(context.trCount('daysApart', days), style: text.labelLarge?.copyWith(color: MashtalColors.forest)),
                ),
            ],
          ),
          const SizedBox(height: MashtalSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              side(first, context.tr('then')),
              const SizedBox(width: MashtalSpace.md),
              side(latest, context.tr('nowLabel')),
            ],
          ),
        ],
      ),
    );
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
          decoration: BoxDecoration(
            border: Border.all(color: MashtalColors.line),
            borderRadius: BorderRadius.circular(MashtalSpace.radius),
          ),
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
    HistoryKind.photo => Icons.photo_camera_back_outlined,
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
                  if (item.text != null) ...[const SizedBox(height: MashtalSpace.xs), Text(item.text!, style: text.bodyMedium)],
                  if (item.photo != null) ...[
                    const SizedBox(height: MashtalSpace.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MashtalSpace.radius),
                      child: Image.memory(decodePhoto(item.photo!), width: 120, height: 120, fit: BoxFit.cover),
                    ),
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
