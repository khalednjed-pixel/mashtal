import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'garden_art.dart';

/// Asks where a garden plant lives, as four big picture tiles. [current] is
/// marked; when [guessed] it is labelled "our pick", so a customer who is not
/// sure can move on. Returns null when dismissed.
///
/// Without [onConfirm] a tap on a tile answers at once (changing where a
/// plant lives). With it, a tap only selects and one button ([confirmLabel])
/// runs [onConfirm]: the sheet stays open while it saves and says so if the
/// save fails, instead of closing as if it had worked.
Future<PlantHome?> pickHome(
  BuildContext context, {
  required PlantHome current,
  required bool guessed,
  String? confirmLabel,
  Future<void> Function(PlantHome home)? onConfirm,
}) {
  return showModalBottomSheet<PlantHome>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => _HomeSheet(current: current, guessed: guessed, confirmLabel: confirmLabel, onConfirm: onConfirm),
  );
}

class _HomeSheet extends StatefulWidget {
  const _HomeSheet({required this.current, required this.guessed, this.confirmLabel, this.onConfirm});
  final PlantHome current;
  final bool guessed;
  final String? confirmLabel;
  final Future<void> Function(PlantHome home)? onConfirm;

  @override
  State<_HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends State<_HomeSheet> {
  late PlantHome _selected = widget.current;
  bool _busy = false;
  bool _failed = false;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onConfirm!(_selected);
      if (mounted) Navigator.pop(context, _selected);
    } catch (e) {
      debugPrint('pickHome: save failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final confirming = widget.onConfirm != null;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.lg),
          child: Column(
            key: const Key('homePicker'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('whereLives'), style: text.titleLarge),
              const SizedBox(height: MashtalSpace.xs),
              Text(context.tr('whereLivesBody'), style: text.bodyMedium),
              const SizedBox(height: MashtalSpace.lg),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: MashtalSpace.md,
                  crossAxisSpacing: MashtalSpace.md,
                  mainAxisExtent: 150,
                ),
                children: [
                  for (final h in PlantHome.values)
                    _HomeTile(
                      home: h,
                      selected: h == _selected,
                      guess: widget.guessed && h == widget.current,
                      onTap: _busy
                          ? null
                          : confirming
                              ? () => setState(() {
                                    _selected = h;
                                    _failed = false;
                                  })
                              : () => Navigator.pop(context, h),
                    ),
                ],
              ),
              if (confirming) ...[
                if (_failed) ...[
                  const SizedBox(height: MashtalSpace.md),
                  Container(
                    key: const Key('homeConfirmFailed'),
                    padding: const EdgeInsets.all(MashtalSpace.md),
                    decoration: BoxDecoration(
                      color: MashtalColors.errorSoft,
                      borderRadius: BorderRadius.circular(MashtalSpace.radius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: MashtalColors.error),
                        const SizedBox(width: MashtalSpace.sm),
                        Expanded(
                          child: Text(context.tr('gardenAddFailed'), style: text.bodyMedium?.copyWith(color: MashtalColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: MashtalSpace.lg),
                FilledButton(
                  key: const Key('homeConfirm'),
                  onPressed: _busy ? null : _confirm,
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.confirmLabel ?? context.tr('addToMyGarden')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The drawing for each place.
Art homeArt(PlantHome h) => switch (h) {
  PlantHome.ground => Art.ground,
  PlantHome.bigPot => Art.bigPot,
  PlantHome.smallPot => Art.smallPot,
  PlantHome.indoor => Art.indoor,
};

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.home, required this.selected, required this.guess, required this.onTap});
  final PlantHome home;
  final bool selected;
  final bool guess;
  final VoidCallback? onTap;

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
        child: Semantics(
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.all(MashtalSpace.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GardenArt(homeArt(home), size: 56),
                const SizedBox(height: MashtalSpace.sm),
                Text(context.tr('home.${home.name}'), style: text.titleMedium, textAlign: TextAlign.center),
                if (guess) Text(context.tr('ourGuess'), style: text.bodySmall?.copyWith(color: MashtalColors.leaf)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
