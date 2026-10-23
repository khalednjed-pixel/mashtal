import '../models/models.dart';

/// Which signed-in state a route needs (US-01, US-04).
enum RouteAccess { public, signedIn, customer, nursery, professional, admin }

/// Access rule for a location. Unknown paths are public and fall through to
/// the router's not-found handling.
RouteAccess accessFor(String path) {
  if (path.startsWith('/admin')) return RouteAccess.admin;
  if (path.startsWith('/nursery')) return RouteAccess.nursery;
  if (path.startsWith('/pro')) return RouteAccess.professional;
  if (path.startsWith('/garden')) return RouteAccess.customer;
  if (path.startsWith('/account')) return RouteAccess.signedIn;
  return RouteAccess.public;
}

/// The home screen of each role.
String homeFor(Role? role) => switch (role) {
      null || Role.customer => '/shop',
      Role.nursery => '/nursery',
      Role.professional => '/pro',
      Role.admin => '/admin',
    };

/// Paths a guest or customer can use. Partners do not see the shop tabs.
bool _isCustomerArea(String path) =>
    path.startsWith('/shop') || path.startsWith('/cart') || path.startsWith('/garden');

/// The admin may browse the shop to check what customers see, but has no cart.
bool _adminMayBrowse(String path) => path.startsWith('/shop');

sealed class AccessDecision {
  const AccessDecision();
}

class Allowed extends AccessDecision {
  const Allowed();
}

/// Not signed in: send to sign-in and come back to [from] afterwards.
class NeedSignIn extends AccessDecision {
  const NeedSignIn(this.from);
  final String from;
}

/// Signed in with the wrong role: send home and say access was denied.
class Denied extends AccessDecision {
  const Denied(this.home);
  final String home;
}

/// Decides whether a user with [role] (null for a guest) may open [location].
AccessDecision decideAccess(String location, Role? role) {
  final path = Uri.parse(location).path;
  final need = accessFor(path);
  if (role == null) {
    return switch (need) {
      RouteAccess.public => const Allowed(),
      _ => NeedSignIn(location),
    };
  }
  final ok = switch (need) {
    RouteAccess.public => role == Role.customer || !_isCustomerArea(path) || (role == Role.admin && _adminMayBrowse(path)),
    RouteAccess.signedIn => true,
    RouteAccess.customer => role == Role.customer,
    RouteAccess.nursery => role == Role.nursery,
    RouteAccess.professional => role == Role.professional,
    RouteAccess.admin => role == Role.admin,
  };
  return ok ? const Allowed() : Denied(homeFor(role));
}
