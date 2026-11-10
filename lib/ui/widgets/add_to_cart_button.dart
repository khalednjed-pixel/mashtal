import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Round emerald add-to-cart button for one nursery's listing, used on the
/// plant page's "Where to find it" list and in the Choose results'
/// "Nurseries that have it" sheet.
///
/// With [showCount] the button carries a badge with how many are already in
/// the cart and greys out once the cart holds all the stock, instead of a
/// snack bar (a snack bar would sit hidden behind a bottom sheet).
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({super.key, required this.listing, this.showCount = false});
  final Listing listing;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final inCart = app.cart[listing.id] ?? 0;
    final full = showCount && app.roomFor(listing.id) <= 0;
    final button = IconButton.filled(
      key: Key('add-${listing.id}'),
      tooltip: context.tr('addToCart'),
      icon: const Icon(Icons.add_shopping_cart, size: 22),
      style: IconButton.styleFrom(backgroundColor: MashtalColors.emerald, foregroundColor: MashtalColors.forestDeep, fixedSize: const Size(48, 48)).copyWith(
        backgroundBuilder: full
            ? null
            : (context, states, child) => DecoratedBox(
                decoration: const BoxDecoration(gradient: MashtalColors.emeraldBlend, shape: BoxShape.circle),
                child: child,
              ),
      ),
      onPressed: full
          ? null
          : () {
              final added = context.read<AppState>().addToCart(listing.id);
              if (showCount) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(context.tr(added ? 'addedToCart' : 'maxStockReached')), duration: const Duration(seconds: 1)));
            },
    );
    if (!showCount) return button;
    return Badge(
      key: Key('inCart-${listing.id}'),
      isLabelVisible: inCart > 0,
      label: Text('$inCart'),
      backgroundColor: MashtalColors.forestDeep,
      child: button,
    );
  }
}
