import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';

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
          _Tab('/pro', 'jobs', Icons.handyman_outlined, Icons.handyman),
          _Tab('/account', 'account', Icons.person_outline, Icons.person),
        ],
      Role.admin => const [
          _Tab('/admin/nurseries', 'nurseries', Icons.storefront_outlined, Icons.storefront),
          _Tab('/admin/professionals', 'professionals', Icons.engineering_outlined, Icons.engineering),
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

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.path == '/cart' ? _CartBadge(count: app.cartCount, child: Icon(t.icon)) : Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: context.tr(t.label),
            ),
        ],
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
