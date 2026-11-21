import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Heart that saves a plant to come back to later. [onPhoto] draws it as a
/// small white disc for sitting on top of a photo; otherwise it is a plain
/// app bar icon. The heart grows in when the plant is saved.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.plantId, this.onPhoto = false});
  final String plantId;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.canShop) return const SizedBox.shrink();
    final saved = app.isSaved(plantId);
    final heart = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Icon(
        saved ? Icons.favorite : Icons.favorite_border,
        key: ValueKey(saved),
        size: onPhoto ? 20 : 24,
        color: saved ? MashtalColors.leaf : (onPhoto ? MashtalColors.forestDeep : null),
      ),
    );
    return IconButton(
      key: Key('save-$plantId'),
      tooltip: context.tr(saved ? 'unsavePlant' : 'savePlant'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: onPhoto
          ? DecoratedBox(
              decoration: const BoxDecoration(color: MashtalColors.surface, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 34, child: Center(child: heart)),
            )
          : heart,
      onPressed: () {
        final now = context.read<AppState>().toggleSaved(plantId);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.tr(now ? 'savedDone' : 'unsavedDone')), duration: const Duration(seconds: 1)));
      },
    );
  }
}
