import 'package:go_router/go_router.dart';

import 'logic/access.dart';
import 'state/app_state.dart';
import 'ui/account_screen.dart';
import 'ui/admin/admin_screen.dart';
import 'ui/admin/nursery_form_screen.dart';
import 'ui/admin/professional_form_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/profile_screen.dart';
import 'ui/customer/cart_screen.dart';
import 'ui/customer/garden_screen.dart';
import 'ui/customer/nursery_detail_screen.dart';
import 'ui/customer/plant_detail_screen.dart';
import 'ui/customer/shop_screen.dart';
import 'ui/nursery/listing_form_screen.dart';
import 'ui/nursery/listings_screen.dart';
import 'ui/nursery/reservations_screen.dart';
import 'ui/pro/pro_home_screen.dart';
import 'ui/role_shell.dart';
import 'ui/widgets/not_found.dart';

GoRouter buildRouter(AppState app) => GoRouter(
      initialLocation: '/',
      refreshListenable: app,
      redirect: (context, state) => _redirect(app, state.uri),
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => homeFor(app.role)),
        GoRoute(
          path: '/login',
          builder: (_, state) => LoginScreen(from: state.uri.queryParameters['from']),
          routes: [
            GoRoute(
              path: 'profile',
              builder: (_, state) => ProfileScreen(
                phone: state.uri.queryParameters['phone'] ?? '',
                from: state.uri.queryParameters['from'],
              ),
            ),
          ],
        ),
        ShellRoute(
          builder: (_, state, child) => RoleShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/shop',
              builder: (_, _) => const ShopScreen(),
              routes: [
                GoRoute(path: 'plant/:id', builder: (_, s) => PlantDetailScreen(plantId: s.pathParameters['id']!)),
                GoRoute(path: 'nursery/:id', builder: (_, s) => NurseryDetailScreen(nurseryId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
            GoRoute(path: '/garden', builder: (_, _) => const GardenScreen()),
            GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
            GoRoute(
              path: '/nursery',
              builder: (_, _) => const ListingsScreen(),
              routes: [
                GoRoute(path: 'listing/new', builder: (_, _) => const ListingFormScreen()),
                GoRoute(path: 'listing/:id', builder: (_, s) => ListingFormScreen(listingId: s.pathParameters['id'])),
                GoRoute(path: 'reservations', builder: (_, _) => const ReservationsScreen()),
              ],
            ),
            GoRoute(
              path: '/admin',
              redirect: (_, s) => s.uri.path == '/admin' ? '/admin/nurseries' : null,
              routes: [
                GoRoute(
                  path: 'nurseries',
                  builder: (_, _) => const AdminScreen(tab: AdminTab.nurseries),
                  routes: [GoRoute(path: 'new', builder: (_, _) => const NurseryFormScreen())],
                ),
                GoRoute(
                  path: 'professionals',
                  builder: (_, _) => const AdminScreen(tab: AdminTab.professionals),
                  routes: [GoRoute(path: 'new', builder: (_, _) => const ProfessionalFormScreen())],
                ),
              ],
            ),
            GoRoute(path: '/pro', builder: (_, _) => const ProHomeScreen()),
          ],
        ),
      ],
    );

String? _redirect(AppState app, Uri uri) {
  final role = app.role;
  if (uri.path == '/login' || uri.path.startsWith('/login/')) {
    if (role == null) return null;
    // Signed in: go back where the user came from if their role may see it.
    final from = uri.queryParameters['from'];
    if (from != null && decideAccess(from, role) is Allowed) return from;
    return homeFor(role);
  }
  return switch (decideAccess(uri.toString(), role)) {
    Allowed() => null,
    NeedSignIn(:final from) => Uri(path: '/login', queryParameters: {'from': from}).toString(),
    Denied(:final home) => () {
        app.postNotice('accessDenied');
        return home;
      }(),
  };
}
