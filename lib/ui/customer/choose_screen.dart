import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/citation.dart';
import '../../logic/suitability.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
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
  }

  @override
  State<ChooseScreen> createState() => _ChooseScreenState();
}

class _ChooseScreenState extends State<ChooseScreen> {
  // Kept across visits so coming back from a plant page keeps the results.
  static SuitabilityAnswers? _savedAnswers;
  static int _savedStep = 0;

  late SuitabilityAnswers _answers;
  late int _step;

  /// Set when the customer changes one answer from the results, so they go
  /// straight back to the results afterwards.
  bool _returnToResults = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
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
        title: Text(context.tr(done ? 'resultsTitle' : 'chooseTitle')),
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
      padding: const EdgeInsets.all(16),
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
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.tr('resultsHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final (i, r) in results.indexed) _ResultCard(rank: i + 1, score: r, answers: answers),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
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
    final theme = Theme.of(context);
    final citation = citationFor(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          key: Key('result-${p.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => showNurseryCompare(context, p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlantPhoto(plant: p),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$rank. ${p.name(context.lang)}', style: theme.textTheme.titleMedium),
                          Text(p.description(context.lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ScoreBadge(total: score.total),
                  ],
                ),
                const SizedBox(height: 10),
                // US-09 AC-01: per-factor breakdown.
                for (final f in Factor.values) _FactorBar(label: factorLabel(context, f, answers), value: score.factors[f]!),
                const SizedBox(height: 6),
                // US-10 AC-01 / US-11: citation, or a label for non-guide plants.
                InkWell(
                  key: Key('citation-${p.id}'),
                  onTap: () => showScoreExplanation(context, score, answers),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(citation == null ? Icons.info_outline : Icons.menu_book_outlined, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            citation == null
                                ? context.tr(p.isCustom ? 'addedByNursery' : 'notGuideBacked')
                                : '${citation.guide} · ${citation.edition} · ${context.tr('section')}: ${citation.section}',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                        Text(context.tr('whyThisScore'), style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text('$total%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
        Text(context.tr('match'), style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _FactorBar extends StatelessWidget {
  const _FactorBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = value >= 70 ? theme.colorScheme.primary : (value >= 40 ? const Color(0xFFE0A100) : theme.colorScheme.error);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
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
                      ? '${c.tr('source')}: ${p.source}'
                      : '${citation.publisher} — ${citation.guide}\n${c.tr('edition')}: ${citation.edition} · ${c.tr('section')}: ${citation.section}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {0: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth()},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const SizedBox(),
                        _cell(c, c.tr('yourAnswer'), bold: true),
                        _cell(c, c.tr('plantNeeds'), bold: true),
                        const SizedBox(),
                      ],
                    ),
                    for (final (label, mine, needs, value) in rows)
                      TableRow(
                        children: [
                          _cell(c, label, bold: true),
                          _cell(c, mine),
                          _cell(c, needs),
                          _cell(c, value == null ? '✓' : '$value'),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _cell(BuildContext c, String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, style: bold ? Theme.of(c).textTheme.labelLarge : Theme.of(c).textTheme.bodyMedium),
    );

/// US-12: verified nurseries that have the plant in stock, cheapest first,
/// with price, rating and city.
Future<void> showNurseryCompare(BuildContext context, Plant plant) {
  final market = context.read<AppState>().backend;
  final offers = [
    for (final l in market.listings)
      if (l.plantId == plant.id && l.isAvailable)
        if (market.nurseryById(l.nurseryId) case final n? when n.isVerified) (l, n),
  ]..sort((a, b) => a.$1.price.compareTo(b.$1.price));

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
                          trailing: Text(formatPrice(c, listing.price), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
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
