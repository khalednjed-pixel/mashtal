import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/access.dart';
import 'package:mashtal/models/models.dart';

void main() {
  group('guest (US-01)', () {
    test('can open Buy Plants, plant pages and the cart', () {
      for (final path in ['/shop', '/shop/plant/p01', '/shop/nursery/n1', '/cart']) {
        expect(decideAccess(path, null), isA<Allowed>(), reason: path);
      }
    });

    test('is sent to sign-in for My Garden and comes back afterwards', () {
      final d = decideAccess('/garden', null);
      expect(d, isA<NeedSignIn>());
      expect((d as NeedSignIn).from, '/garden');
    });
  });

  group('roles (US-04)', () {
    test('customer opening an admin or nursery route is denied and sent home', () {
      for (final path in ['/admin/nurseries', '/nursery', '/nursery/listing/new', '/pro']) {
        final d = decideAccess(path, Role.customer);
        expect(d, isA<Denied>(), reason: path);
        expect((d as Denied).home, '/shop');
      }
    });

    test('nursery cannot see customer tabs or admin pages', () {
      for (final path in ['/shop', '/cart', '/garden', '/admin/nurseries']) {
        final d = decideAccess(path, Role.nursery);
        expect(d, isA<Denied>(), reason: path);
        expect((d as Denied).home, '/nursery');
      }
    });

    test('each role reaches its own home and the account page', () {
      expect(decideAccess('/nursery', Role.nursery), isA<Allowed>());
      expect(decideAccess('/admin/professionals', Role.admin), isA<Allowed>());
      expect(decideAccess('/pro', Role.professional), isA<Allowed>());
      expect(decideAccess('/garden', Role.customer), isA<Allowed>());
      for (final role in Role.values) {
        expect(decideAccess('/account', role), isA<Allowed>());
      }
    });
  });

  test('home of each role', () {
    expect(homeFor(null), '/shop');
    expect(homeFor(Role.customer), '/shop');
    expect(homeFor(Role.nursery), '/nursery');
    expect(homeFor(Role.professional), '/pro');
    expect(homeFor(Role.admin), '/admin');
  });
}
