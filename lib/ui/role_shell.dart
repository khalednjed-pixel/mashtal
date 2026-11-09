import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'theme.dart';

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom navigation that only shows the tabs of the signed-in role (US-04).
List<_Tab> _tabsFor(Role? role) => switch (role) {
  null || Role.customer => const [
    _Tab('/shop', 'buyPlants', Icons.storefront_outlined, Icons.storefront),
    _Tab('/garden', 'myGarden', Icons.yard_outlined, Icons.yard),
    _Tab('/cart', 'cart', Icons.shopping_basket_outlined, Icons.shopping_basket),
    _Tab('/account', 'account', Icons.person_outline, Icons.person),
  ],
  Role.nursery => const [
    _Tab('/nursery', 'myListings', Icons.inventory_2_outlined, Icons.inventory_2),
    _Tab('/nursery/reservations', 'reservations', Icons.receipt_long_outlined, Icons.receipt_long),
    _Tab('/account', 'account', Icons.person_outline, Icons.person),
  ],
  Role.professional => const [
    _Tab('/pro', 'myProfile', Icons.handyman_outlined, Icons.handyman),
    _Tab('/account', 'account', Icons.person_outline, Icons.person),
  ],
  Role.admin => const [
    _Tab('/admin/nurseries', 'nurseries', Icons.storefront_outlined, Icons.storefront),
    _Tab('/admin/professionals', 'professionals', Icons.engineering_outlined, Icons.engineering),
    _Tab('/admin/plants', 'plantData', Icons.eco_outlined, Icons.eco),
    _Tab('/shop', 'buyPlants', Icons.local_florist_outlined, Icons.local_florist),
    _Tab('/account', 'account', Icons.person_outline, Icons.person),
  ],
};

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  late final ValueNotifier<String?> _notice = context.read<AppState>().notice;

  @override
  void initState() {
    super.initState();
    _notice.addListener(_onNotice);
    _onNotice();
  }

  @override
  void dispose() {
    _notice.removeListener(_onNotice);
    super.dispose();
  }

  // Posted from the router's redirect, so show it after the current frame.
  void _onNotice() {
    if (_notice.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _notice.value;
      if (!mounted || key == null) return;
      _notice.value = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tabs = _tabsFor(app.role);
    // Longest matching prefix wins, so /nursery/reservations beats /nursery.
    var index = -1;
    var best = 0;
    for (final (i, t) in tabs.indexed) {
      if (widget.location.startsWith(t.path) && t.path.length > best) {
        index = i;
        best = t.path.length;
      }
    }

    // extendBody: pages scroll on under and around the floating pill instead
    // of stopping above a solid strip; lists add [clearNav] so their last item
    // can still scroll clear of it.
    return Scaffold(
      extendBody: true,
      body: SelectionArea(child: widget.child),
      bottomNavigationBar: _FloatingNav(
        selected: index < 0 ? 0 : index,
        onSelect: (i) => context.go(tabs[i].path),
        items: [
          for (final t in tabs)
            (
              icon: t.path == '/cart' ? _CartBadge(count: app.cartCount, child: Icon(t.icon)) : Icon(t.icon),
              // On the cart tab itself the count is on screen, so no badge.
              selectedIcon: Icon(t.selectedIcon),
              label: context.tr(t.label),
            ),
        ],
      ),
    );
  }
}

typedef _NavItem = ({Widget icon, Widget selectedIcon, String label});

/// Floating pill navigation: lifted off the bottom edge with a soft shadow,
/// the current tab filled with the emerald blend.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.selected, required this.onSelect, required this.items});
  final int selected;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: MashtalSpace.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(MashtalSpace.lg, MashtalSpace.sm, MashtalSpace.lg, 0),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MashtalColors.surface,
                borderRadius: BorderRadius.circular(MashtalSpace.pill),
                boxShadow: const [BoxShadow(color: MashtalColors.shadow, blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    for (final (i, item) in items.indexed)
                      Expanded(
                        child: Semantics(
                          selected: i == selected,
                          button: true,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () => onSelect(i),
                              customBorder: const StadiumBorder(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                height: 60,
                                decoration: ShapeDecoration(
                                  shape: const StadiumBorder(),
                                  gradient: i == selected ? MashtalColors.emeraldBlend : null,
                                ),
                                // Side padding keeps neighbouring labels apart.
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconTheme(
                                      data: IconThemeData(size: 24, color: i == selected ? MashtalColors.forestDeep : MashtalColors.muted),
                                      child: i == selected ? item.selectedIcon : item.icon,
                                    ),
                                    const SizedBox(height: 2),
                                    // Shrinks long labels (five admin tabs) instead of cutting them.
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        style: i == selected
                                            ? text.labelSmall?.copyWith(color: MashtalColors.forestDeep, fontWeight: FontWeight.w700)
                                            : text.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(isLabelVisible: count > 0, label: Text('$count'), child: child);
}
