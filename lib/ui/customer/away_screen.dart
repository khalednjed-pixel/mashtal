import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/away.dart';
import '../../logic/care_plan.dart';
import '../../logic/share.dart' show whatsAppShare;
import '../../logic/watering.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/garden_art.dart';
import '../widgets/pickup_pass.dart' show openExternal;
import '../widgets/plant_photo.dart';

/// Going away: two plain questions (how long, will someone at home water),
/// then either a watering plan to send to whoever waters, or what to do
/// before leaving and which plants will not last alone.
class AwayScreen extends StatefulWidget {
  const AwayScreen({super.key});

  @override
  State<AwayScreen> createState() => _AwayScreenState();
}

class _AwayScreenState extends State<AwayScreen> {
  static const _quick = [3, 7, 14, 30];
  DateTime? _until;
  bool? _helper;
  String? _messageLang;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int? get _days => _until?.difference(_today).inDays;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _today.add(const Duration(days: 1)),
      lastDate: _today.add(const Duration(days: 120)),
      initialDate: _until ?? _today.add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _until = picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final market = app.backend;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final plants = [
      for (final g in market.garden)
        if (market.plantById(g.plantId) case final p?) (garden: g, plant: p, plan: CarePlan.of(g, p, now)),
    ];
    final days = _days;
    final trip = days == null || _helper == null ? null : AwayTrip(from: _today, until: _until!, helper: _helper!);
    final untilText = _until == null ? '' : DateFormat('EEEE d MMMM', lang).format(_until!);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/garden')),
        title: Text(context.tr('awayTitle')),
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            const Center(child: GardenArt(Art.suitcase, size: 112)),
            const SizedBox(height: MashtalSpace.md),
            Text(context.tr('awayHowLong'), style: text.titleLarge),
            const SizedBox(height: MashtalSpace.md),
            Wrap(
              spacing: MashtalSpace.sm,
              runSpacing: MashtalSpace.sm,
              children: [
                for (final d in _quick)
                  ChoiceChip(
                    key: Key('away-$d'),
                    label: Text(context.tr('away.$d')),
                    selected: days == d,
                    onSelected: (_) => setState(() => _until = _today.add(Duration(days: d))),
                  ),
                ActionChip(
                  key: const Key('awayPickDate'),
                  avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(context.tr('awayPickDate')),
                  onPressed: _pickDate,
                ),
              ],
            ),
            if (_until != null)
              Padding(
                padding: const EdgeInsets.only(top: MashtalSpace.sm),
                child: Text('${context.tr('awayBackOn')} $untilText', key: const Key('awayBackOn'), style: text.bodyMedium),
              ),
            const SizedBox(height: MashtalSpace.xl),
            Text(context.tr('awayHelperQ'), style: text.titleLarge),
            const SizedBox(height: MashtalSpace.md),
            _Choice(
              id: 'helper-yes',
              art: Art.helper,
              title: context.tr('awayHelperYes'),
              body: context.tr('awayHelperYesBody'),
              selected: _helper == true,
              onTap: () => setState(() => _helper = true),
            ),
            const SizedBox(height: MashtalSpace.sm),
            _Choice(
              id: 'helper-no',
              art: Art.suitcase,
              title: context.tr('awayHelperNo'),
              body: context.tr('awayHelperNoBody'),
              selected: _helper == false,
              onTap: () => setState(() => _helper = false),
            ),
            if (trip != null) ...[
              const SizedBox(height: MashtalSpace.xl),
              if (trip.helper) ..._helperPlan(context, plants, untilText) else ..._onTheirOwn(context, plants, trip),
              const SizedBox(height: MashtalSpace.xl),
              FilledButton.icon(
                key: const Key('awayStart'),
                icon: const Icon(Icons.flight_takeoff),
                label: Text(context.tr('awayStart')),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final msg = context.tr('awayStarted');
                  app.startAway(trip);
                  context.go('/garden');
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Someone at home waters: the plan to send them, in the language they read.
  List<Widget> _helperPlan(BuildContext context, List<({GardenPlant garden, Plant plant, CarePlan plan})> plants, String untilText) {
    final text = Theme.of(context).textTheme;
    final lang = _messageLang ?? context.lang;
    final message = helperMessage(
      lang: lang,
      untilText: DateFormat('EEEE d MMMM', lang).format(_until!),
      plants: [for (final p in plants) (name: p.plant.name(lang), home: p.plan.home, everyDays: p.plan.everyDays)],
      season: riyadhSeason(DateTime.now()),
    );
    return [
      Text(context.tr('awayPlanFor'), style: text.titleLarge),
      const SizedBox(height: MashtalSpace.md),
      Row(
        children: [
          Expanded(child: Text(context.tr('awayPlanLang'), style: text.bodyMedium)),
          SegmentedButton<String>(
            key: const Key('awayLang'),
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {lang},
            onSelectionChanged: (v) => setState(() => _messageLang = v.first),
          ),
        ],
      ),
      const SizedBox(height: MashtalSpace.md),
      Container(
        key: const Key('awayMessage'),
        padding: const EdgeInsets.all(MashtalSpace.md),
        decoration: BoxDecoration(color: MashtalColors.waterSoft, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
        child: Text(message, textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr, style: text.bodyMedium),
      ),
      const SizedBox(height: MashtalSpace.md),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('awaySendPlan'),
              icon: const Icon(Icons.chat_outlined),
              label: Text(context.tr('awaySendPlan')),
              onPressed: () => openExternal(whatsAppShare(message)),
            ),
          ),
          const SizedBox(width: MashtalSpace.sm),
          IconButton.outlined(
            key: const Key('awayCopyPlan'),
            tooltip: context.tr('copyLink'),
            style: IconButton.styleFrom(side: const BorderSide(color: MashtalColors.leaf)),
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final done = context.tr('linkCopied');
              await Clipboard.setData(ClipboardData(text: message));
              messenger.showSnackBar(SnackBar(content: Text(done)));
            },
          ),
        ],
      ),
    ];
  }

  /// Nobody waters: a short checklist, then which plants will not last.
  List<Widget> _onTheirOwn(BuildContext context, List<({GardenPlant garden, Plant plant, CarePlan plan})> plants, AwayTrip trip) {
    final text = Theme.of(context).textTheme;
    final lang = context.lang;
    final help = needsHelp([for (final p in plants) (garden: p.garden, plan: p.plan)], trip);
    return [
      Text(context.tr('awayBefore'), style: text.titleLarge),
      const SizedBox(height: MashtalSpace.md),
      for (final (i, step) in ['awayStep1', 'awayStep2', 'awayStep3'].indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: MashtalSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: MashtalColors.mint,
                child: Text('${i + 1}', style: text.labelLarge?.copyWith(color: MashtalColors.forest)),
              ),
              const SizedBox(width: MashtalSpace.md),
              Expanded(child: Text(context.tr(step), style: text.bodyLarge)),
            ],
          ),
        ),
      const SizedBox(height: MashtalSpace.sm),
      if (help.isEmpty)
        Container(
          key: const Key('awayAllFine'),
          padding: const EdgeInsets.all(MashtalSpace.md),
          decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: MashtalColors.leaf),
              const SizedBox(width: MashtalSpace.md),
              Expanded(child: Text(context.tr('awayAllFine'), style: text.bodyLarge)),
            ],
          ),
        )
      else ...[
        Text(context.tr('awayAtRisk'), style: text.titleMedium),
        const SizedBox(height: MashtalSpace.sm),
        for (final h in help)
          if (plants.where((p) => p.garden.id == h.gardenId).firstOrNull case final p?)
            Padding(
              key: Key('atRisk-${h.gardenId}'),
              padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
              child: Container(
                padding: const EdgeInsets.all(MashtalSpace.sm),
                decoration: BoxDecoration(color: MashtalColors.sand, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                child: Row(
                  children: [
                    PlantPhoto(plant: p.plant, size: 48),
                    const SizedBox(width: MashtalSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.plant.name(lang), style: text.titleMedium),
                          Text(
                            h.times <= 1
                                ? '${context.tr('awayWaterOnce')} ${DateFormat('EEEE d MMMM', lang).format(h.waterOn)}'
                                : context.tr('awayWaterEvery').replaceAll('{every}', wateringEveryText(lang, h.everyDays)),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ];
  }
}

/// A big tappable answer card with a drawing, a title and one line of help.
class _Choice extends StatelessWidget {
  const _Choice({required this.id, required this.art, required this.title, required this.body, required this.selected, required this.onTap});
  final String id;
  final Art art;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? MashtalColors.mint : MashtalColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MashtalSpace.radius),
        side: BorderSide(color: selected ? MashtalColors.leaf : MashtalColors.line, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        key: Key(id),
        borderRadius: BorderRadius.circular(MashtalSpace.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MashtalSpace.lg),
          child: Row(
            children: [
              GardenArt(art, size: 52, fill: selected ? MashtalColors.surface : MashtalColors.mint),
              const SizedBox(width: MashtalSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(body, style: text.bodyMedium),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: MashtalColors.leaf),
            ],
          ),
        ),
      ),
    );
  }
}
