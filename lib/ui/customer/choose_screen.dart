import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/citation.dart';
import '../../logic/suitability.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_to_cart_button.dart';
import '../widgets/common.dart';
import '../widgets/plant_photo.dart';

/// "What suits your place?": the suitability questions (US-07, US-08) and
/// the ranked, cited results (US-09 to US-12). Works for guests (US-01).
class ChooseScreen extends StatefulWidget {
  const ChooseScreen({super.key});

  /// Clears the answers kept between visits. Tests call this between cases.
  @visibleForTesting
  static void resetSaved() {
    _ChooseScreenState._savedAnswers = null;
    _ChooseScreenState._savedStep = 0;
    _ChooseScreenState._savedFor = null;
  }

  @override
  State<ChooseScreen> createState() => _ChooseScreenState();
}

class _ChooseScreenState extends State<ChooseScreen> {
  // Kept across visits so coming back from a plant page keeps the results.
  static SuitabilityAnswers? _savedAnswers;
  static int _savedStep = 0;

  /// Who the saved answers belong to (null for a guest). Another account on
  /// the same device starts fresh instead of seeing them.
  static String? _savedFor;

  late SuitabilityAnswers _answers;
  late int _step;

  /// Set when the customer changes one answer from the results, so they go
  /// straight back to the results afterwards.
  bool _returnToResults = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    if (_savedFor != user?.id) {
      _savedAnswers = null;
      _savedStep = 0;
      _savedFor = user?.id;
    }
    _answers = _savedAnswers ?? SuitabilityAnswers(city: user?.city);
    _step = _savedStep;
  }

  /// The question on screen: never past the first one still unanswered.
  int get _currentStep {
    final questions = _answers.questions;
    final open = questions.indexWhere((q) => !_answers.isAnswered(q));
    if (open >= 0 && open < _step) return open;
    return _step > questions.length ? questions.length : _step;
  }

  void _set(SuitabilityAnswers a) {
    setState(() {
      _step = _returnToResults && a.isComplete ? a.questions.length : _currentStep + 1;
      _returnToResults = false;
      _answers = a;
      _savedAnswers = _answers;
      _savedStep = _step;
    });
  }

  void _goTo(int step) => setState(() {
        _step = step;
        _savedStep = step;
      });

  void _restart() => setState(() {
        _returnToResults = false;
        _answers = SuitabilityAnswers(city: context.read<AppState>().user?.city);
        _step = 0;
        _savedAnswers = null;
        _savedStep = 0;
      });

  /// US-08: skipping opens Buy Plants with no suitability filter.
  void _skip() => context.go('/shop');

  @override
  Widget build(BuildContext context) {
    final questions = _answers.questions;
    final step = _currentStep;
    final done = step >= questions.length && _answers.isComplete;
    return Scaffold(
      appBar: AppBar(
        // The results title is long; it is shown in the page instead, where it
        // can wrap rather than be cut off.
        title: done ? null : Text(context.tr('chooseTitle')),
        // Next to the back arrow, no extra gap, so the title fits at 375 px.
        titleSpacing: step > 0 ? 0 : null,
        leading: step > 0
            ? IconButton(
                key: const Key('chooseBack'),
                tooltip: context.tr('back'),
                icon: const BackButtonIcon(),
                onPressed: () => _goTo(step - 1),
              )
            : null,
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        child: done ? _Results(answers: _answers, onChange: _changeQuestion, onRestart: _restart) : _questionView(questions, step),
      ),
    );
  }

  void _changeQuestion(Question q) {
    final i = _answers.questions.indexOf(q);
    _returnToResults = true;
    _goTo(i < 0 ? 0 : i);
  }

  Widget _questionView(List<Question> questions, int current) {
    final step = current >= questions.length ? questions.length - 1 : current;
    final q = questions[step];
    final theme = Theme.of(context);
    return ListView(
      padding: clearNav(context, const EdgeInsets.all(16)),
      children: [
        // AC-01: one question per screen with a progress bar.
        LinearProgressIndicator(key: const Key('chooseProgress'), value: (step + 1) / questions.length, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        const SizedBox(height: 8),
        Text('${context.tr('questionOf')} ${step + 1} ${context.tr('of')} ${questions.length}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        Text(context.tr('q.${q.name}'), key: Key('question-${q.name}'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ..._options(q),
        const SizedBox(height: 24),
        TextButton.icon(
          key: const Key('skipQuestions'),
          onPressed: _skip,
          icon: const Icon(Icons.storefront_outlined),
          label: Text(context.tr('skip')),
        ),
      ],
    );
  }

  List<Widget> _options(Question q) {
    final a = _answers;
    return switch (q) {
      Question.city => [
          for (final c in cityIds) _Option(id: 'city-$c', label: context.trCity(c), selected: a.city == c, onTap: () => _set(a.copyWith(city: c))),
        ],
      Question.spot => [
          for (final s in Spot.values)
            _Option(id: 'spot-${s.name}', label: context.tr('a.spot.${s.name}'), selected: a.spot == s, onTap: () => _set(a.withSpot(s))),
        ],
      Question.window || Question.sun => [
          for (final v in Amount.values.reversed)
            _Option(
              id: '${q.name}-${v.name}',
              label: context.tr('a.${q.name}.${v.name}'),
              selected: a.light == v,
              onTap: () => _set(a.copyWith(light: v)),
            ),
        ],
      Question.space => [
          for (final v in Amount.values)
            _Option(id: 'space-${v.name}', label: context.tr('a.space.${v.name}'), selected: a.space == v, onTap: () => _set(a.copyWith(space: v))),
        ],
      Question.watering => [
          for (final v in Amount.values)
            _Option(
              id: 'watering-${v.name}',
              label: context.tr('a.watering.${v.name}'),
              selected: a.watering == v,
              onTap: () => _set(a.copyWith(watering: v)),
            ),
        ],
      Question.kidsOrPets => [
          _Option(id: 'kids-yes', label: context.tr('yes'), selected: a.kidsOrPets == true, onTap: () => _set(a.copyWith(kidsOrPets: true))),
          _Option(id: 'kids-no', label: context.tr('no'), selected: a.kidsOrPets == false, onTap: () => _set(a.copyWith(kidsOrPets: false))),
        ],
    };
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.id, required this.label, required this.selected, required this.onTap});
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: selected ? scheme.primaryContainer : null,
        child: ListTile(
          key: Key('option-$id'),
          title: Text(label),
          trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? scheme.primary : null),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Results

class _Results extends StatelessWidget {
  const _Results({required this.answers, required this.onChange, required this.onRestart});
  final SuitabilityAnswers answers;
  final void Function(Question) onChange;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    // Watching the app state means admin edits to plant data show at once (US-14).
    final market = context.watch<AppState>().backend;
    final outcome = recommend(market.plants, answers);
    return switch (outcome) {
      NotCovered() => EmptyState(
          key: const Key('notCovered'),
          icon: Icons.map_outlined,
          title: context.tr('notCoveredTitle'),
          body: context.tr('notCoveredBody'),
          actions: [
            FilledButton(onPressed: () => context.go('/shop'), child: Text(context.tr('browseShop'))),
            TextButton(onPressed: () => onChange(Question.city), child: Text(context.tr('changeAnswer'))),
          ],
        ),
      NothingFits(:final blocker) => EmptyState(
          key: const Key('nothingFits'),
          icon: Icons.filter_alt_off_outlined,
          title: context.tr('nothingFitsTitle'),
          body: '${context.tr('nothingFitsBody')} ${context.tr('q.${questionFor(blocker, answers).name}')}',
          actions: [
            FilledButton(
              key: const Key('changeBlocker'),
              onPressed: () => onChange(questionFor(blocker, answers)),
              child: Text(context.tr('changeAnswer')),
            ),
            TextButton(onPressed: onRestart, child: Text(context.tr('startOver'))),
          ],
        ),
      Ranked(:final results) => ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            Text(context.tr('resultsTitle'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: MashtalSpace.xs),
            Text(context.tr('resultsHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: MashtalSpace.lg),
            for (final (i, r) in results.indexed) _ResultCard(rank: i + 1, score: r, answers: answers),
            const SizedBox(height: MashtalSpace.sm),
            Wrap(
              spacing: MashtalSpace.sm,
              runSpacing: MashtalSpace.sm,
              children: [
                OutlinedButton.icon(onPressed: onRestart, icon: const Icon(Icons.restart_alt), label: Text(context.tr('startOver'))),
                TextButton(onPressed: () => context.go('/shop'), child: Text(context.tr('browseShop'))),
              ],
            ),
          ],
        ),
    };
  }
}

String factorLabel(BuildContext context, Factor f, SuitabilityAnswers a) =>
    f == Factor.light ? context.tr(a.isInside ? 'f.light.inside' : 'f.light.outside') : context.tr('f.${f.name}');

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.rank, required this.score, required this.answers});
  final int rank;
  final PlantScore score;
  final SuitabilityAnswers answers;

  @override
  Widget build(BuildContext context) {
    final p = score.plant;
    final text = Theme.of(context).textTheme;
    final citation = citationFor(p);
    // Same offers the nursery compare sheet lists: verified nurseries with the
    // plant in stock.
    final market = context.watch<AppState>().backend;
    final offers = [
      for (final l in market.listings)
        if (l.plantId == p.id && l.isAvailable)
          if (market.nurseryById(l.nurseryId) case final n? when n.isVerified) (l, n),
    ];
    final lowest = offers.isEmpty ? null : offers.map((o) => o.$1.price).reduce((a, b) => a < b ? a : b);
    final nurseries = offers.map((o) => o.$2.id).toSet().length;
    void compare() => showNurseryCompare(context, p, city: answers.city);

    // A white product box like the shop's: the square photo (never cropped)
    // beside the plant and its match score, then price, the way to buy it and
    // the guide citation.
    return Padding(
      padding: const EdgeInsets.only(bottom: MashtalSpace.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MashtalColors.surface,
          borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
          boxShadow: const [BoxShadow(color: MashtalColors.shadow, blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('result-${p.id}'),
            onTap: compare,
            borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(MashtalSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 116, height: 116, child: PlantPhoto.fill(plant: p, radius: MashtalSpace.radius)),
                      const SizedBox(width: MashtalSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$rank. ${p.name(context.lang)}', style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              p.scientificName,
                              textDirection: TextDirection.ltr,
                              style: text.bodySmall?.copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: MashtalColors.muted),
                            ),
                            const SizedBox(height: MashtalSpace.md),
                            _ScoreRing(total: score.total),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MashtalSpace.md),
                  Text(p.description(context.lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(color: MashtalColors.muted)),
                  const SizedBox(height: MashtalSpace.md),
                  // Price from, nursery count and the one action: where to buy.
                  Row(
                    children: [
                      Expanded(
                        child: lowest == null
                            ? Text(context.tr('notAvailable'), style: text.labelMedium?.copyWith(color: MashtalColors.error))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(context.tr('from'), style: text.bodySmall),
                                      const SizedBox(width: MashtalSpace.xs),
                                      Flexible(child: Text(formatPrice(context, lowest), style: text.titleMedium)),
                                    ],
                                  ),
                                  Text(
                                    nurseries == 1 ? context.tr('oneNursery') : '$nurseries ${context.tr('nurseriesCount')}',
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: MashtalSpace.sm),
                      OutlinedButton.icon(
                        onPressed: compare,
                        icon: const Icon(Icons.storefront_outlined, size: 20),
                        label: Text(context.tr('whereToBuy')),
                      ),
                    ],
                  ),
                  const SizedBox(height: MashtalSpace.md),
                  // US-10 AC-01 / US-11: citation, or a label for non-guide plants.
                  // Opens "Why this score?" with the per-factor breakdown (US-09).
                  Material(
                    color: MashtalColors.ground,
                    borderRadius: BorderRadius.circular(MashtalSpace.radius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('citation-${p.id}'),
                      onTap: () => showScoreExplanation(context, score, answers),
                      child: Padding(
                        padding: const EdgeInsets.all(MashtalSpace.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(citation == null ? Icons.info_outline : Icons.menu_book_outlined, size: 20, color: MashtalColors.leaf),
                            const SizedBox(width: MashtalSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    citation == null
                                        ? context.tr(p.isCustom ? 'addedByNursery' : 'notGuideBacked')
                                        : '${citation.guideIn(context.lang)} · ${citation.editionIn(context.lang)} · ${context.tr('section')}: ${citation.sectionIn(context.lang)}',
                                    style: text.bodySmall?.copyWith(color: MashtalColors.forestDeep),
                                  ),
                                  const SizedBox(height: MashtalSpace.xs),
                                  Text(context.tr('whyThisScore'), style: text.labelMedium?.copyWith(color: MashtalColors.leaf)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: MashtalColors.leaf),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colour for a 0–100 score: strong, middling or weak.
Color scoreColor(int value) => value >= 70 ? MashtalColors.sprout : (value >= 40 ? MashtalColors.muted : MashtalColors.error);

/// The match percentage as a ring: the one visual anchor of a result card.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.total});
  final int total;

  /// A word for the number, so 91% reads as "Great fit for your place".
  static String verdictKey(int total) => total >= 85 ? 'fitGreat' : (total >= 70 ? 'fitGood' : (total >= 40 ? 'fitPartial' : 'fitPoor'));

  /// Text colour of the verdict (emerald itself is too light for text on white).
  static Color verdictColor(int total) => total >= 70 ? MashtalColors.leaf : (total >= 40 ? MashtalColors.muted : MashtalColors.error);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: total / 100,
                  strokeWidth: 5,
                  color: scoreColor(total),
                  backgroundColor: MashtalColors.ground,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text('$total%', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: MashtalColors.forest)),
            ],
          ),
        ),
        const SizedBox(width: MashtalSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(verdictKey(total)), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: verdictColor(total))),
              Text(context.tr('fitForYourPlace'), style: text.bodySmall?.copyWith(color: MashtalColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One factor in "Why this score?": a short bar and the number.
class _FactorBar extends StatelessWidget {
  const _FactorBar({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              color: scoreColor(value),
              backgroundColor: MashtalColors.line,
              borderRadius: BorderRadius.circular(MashtalSpace.pill),
            ),
          ),
          const SizedBox(width: MashtalSpace.sm),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.end, style: text.labelMedium)),
        ],
      ),
    );
  }
}

/// US-10 AC-02: the plant data used in the score, next to the answers.
Future<void> showScoreExplanation(BuildContext context, PlantScore score, SuitabilityAnswers a) {
  final p = score.plant;
  final citation = citationFor(p);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final theme = Theme.of(c);
      String answer(Question q) => switch (q) {
            Question.spot => c.tr('a.spot.${a.spot!.name}'),
            Question.window || Question.sun => c.tr('a.${q.name}.${a.light!.name}'),
            Question.space => c.tr('a.space.${a.space!.name}'),
            Question.watering => c.tr('a.watering.${a.watering!.name}'),
            Question.kidsOrPets => c.tr(a.kidsOrPets! ? 'yes' : 'no'),
            Question.city => c.trCity(a.city!),
          };
      final rows = <(String, String, String, int?)>[
        (c.tr('f.place'), answer(Question.spot), p.placements.map((e) => c.tr('need.place.${e.name}')).join('، '), score.factors[Factor.place]),
        (
          factorLabel(c, Factor.light, a),
          answer(a.isInside ? Question.window : Question.sun),
          c.trEnum(p.sun),
          score.factors[Factor.light]
        ),
        (c.tr('f.water'), answer(Question.watering), '${c.trEnum(p.water)} · ${c.tr('waterEvery')} ${p.wateringEveryDays} ${c.tr('days')}', score.factors[Factor.water]),
        (c.tr('f.space'), answer(Question.space), '${c.tr('need.size.${sizeOf(p).name}')} (${c.trEnum(p.category)})', score.factors[Factor.space]),
        if (a.kidsOrPets == true) (c.tr('f.safety'), answer(Question.kidsOrPets), c.tr('safeForKids'), null),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              key: const Key('scoreExplanation'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${p.name(c.lang)} · ${score.total}%', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  citation == null
                      ? '${c.tr('source')}: ${sourceText(c.lang, p)}'
                      : '${citation.publisherIn(c.lang)} — ${citation.guideIn(c.lang)}\n${c.tr('edition')}: ${citation.editionIn(c.lang)} · ${c.tr('section')}: ${citation.sectionIn(c.lang)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: MashtalSpace.lg),
                // Column headings once; each factor below is its name and bar,
                // then the answer next to what the plant needs.
                Row(
                  children: [
                    Expanded(child: Text(c.tr('yourAnswer'), style: theme.textTheme.labelSmall)),
                    const SizedBox(width: MashtalSpace.md),
                    Expanded(child: Text(c.tr('plantNeeds'), style: theme.textTheme.labelSmall)),
                  ],
                ),
                for (final (label, mine, needs, value) in rows) ...[
                  const SizedBox(height: MashtalSpace.md),
                  const Divider(),
                  const SizedBox(height: MashtalSpace.md),
                  Row(
                    children: [
                      Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
                      value == null
                          ? Text('✓', style: theme.textTheme.titleMedium?.copyWith(color: MashtalColors.sprout))
                          : _FactorBar(value: value),
                    ],
                  ),
                  const SizedBox(height: MashtalSpace.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(mine, style: theme.textTheme.bodyMedium)),
                      const SizedBox(width: MashtalSpace.md),
                      Expanded(child: Text(needs, style: theme.textTheme.bodyMedium?.copyWith(color: MashtalColors.muted))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// US-12: verified nurseries that have the plant in stock, with price,
/// rating and city. Nurseries in the customer's [city] come first, then the
/// rest; cheapest first within each group.
Future<void> showNurseryCompare(BuildContext context, Plant plant, {String? city}) {
  final market = context.read<AppState>().backend;
  final offers = [
    for (final l in market.listings)
      if (l.plantId == plant.id && l.isAvailable)
        if (market.nurseryById(l.nurseryId) case final n? when n.isVerified) (l, n),
  ]..sort((a, b) {
      final aHere = a.$2.city == city, bHere = b.$2.city == city;
      if (aHere != bHere) return aHere ? -1 : 1;
      return a.$1.price.compareTo(b.$1.price);
    });

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final theme = Theme.of(c);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            key: const Key('nurseryCompare'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${c.tr('compareTitle')}: ${plant.name(c.lang)}', style: theme.textTheme.titleLarge),
              if (offers.length > 1) Text(c.tr('cheapestFirst'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (offers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(c.tr('notInNurseries'), key: const Key('notInNurseries'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (listing, nursery) in offers)
                      Card(
                        child: ListTile(
                          key: Key('offer-${listing.id}'),
                          leading: const Icon(Icons.storefront),
                          title: Text(nursery.name(c.lang)),
                          subtitle: Row(children: [RatingLabel(rating: nursery.rating, count: nursery.ratingCount), Text('  ·  ${c.trCity(nursery.city)}')]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatPrice(c, listing.price), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                              // Same add button as the plant page's "Where to find it".
                              if (c.watch<AppState>().canShop) ...[
                                const SizedBox(width: MashtalSpace.sm),
                                AddToCartButton(listing: listing, showCount: true),
                              ],
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(c);
                            context.go('/shop/nursery/${nursery.id}');
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: const Key('openPlant'),
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/shop/plant/${plant.id}');
                },
                child: Text(c.tr('openPlant')),
              ),
            ],
          ),
        ),
      );
    },
  );
}
