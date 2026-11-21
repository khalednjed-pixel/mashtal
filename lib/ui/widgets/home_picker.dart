import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';

/// Asks where a garden plant lives, as four big picture tiles. [current] is
/// marked; when [guessed] it is labelled "our pick", so a customer who is not
/// sure can tap it and move on. Returns null when dismissed.
Future<PlantHome?> pickHome(BuildContext context, {required PlantHome current, required bool guessed}) {
  return showModalBottomSheet<PlantHome>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.lg),
          child: Column(
            key: const Key('homePicker'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sheet.tr('whereLives'), style: text.titleLarge),
              const SizedBox(height: MashtalSpace.xs),
              Text(sheet.tr('whereLivesBody'), style: text.bodyMedium),
              const SizedBox(height: MashtalSpace.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: MashtalSpace.md,
                crossAxisSpacing: MashtalSpace.md,
                childAspectRatio: 1.35,
                children: [
                  for (final h in PlantHome.values)
                    _HomeTile(home: h, selected: h == current, guess: guessed && h == current, onTap: () => Navigator.pop(sheet, h)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The drawing for each place: the pot icon grows with the pot.
IconData homeIcon(PlantHome h) => switch (h) {
      PlantHome.ground => Icons.yard_outlined,
      PlantHome.bigPot || PlantHome.smallPot => Icons.local_florist_outlined,
      PlantHome.indoor => Icons.chair_outlined,
    };

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.home, required this.selected, required this.guess, required this.onTap});
  final PlantHome home;
  final bool selected;
  final bool guess;
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
        key: Key('home-${home.name}'),
        borderRadius: BorderRadius.circular(MashtalSpace.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MashtalSpace.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(homeIcon(home), size: home == PlantHome.smallPot ? 24 : 32, color: MashtalColors.leaf),
              const SizedBox(height: MashtalSpace.sm),
              Text(context.tr('home.${home.name}'), style: text.titleMedium, textAlign: TextAlign.center),
              if (guess) Text(context.tr('ourGuess'), style: text.bodySmall?.copyWith(color: MashtalColors.leaf)),
            ],
          ),
        ),
      ),
    );
  }
}
