import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/professionals.dart';
import 'package:mashtal/models/models.dart';

/// US-24 AC-01: only verified professionals covering the city and service.
void main() {
  List<String> ids(String city, ServiceType s) => [for (final p in professionalsFor(seedProfessionals, city: city, service: s)) p.id];

  test('verified, in the city, offering the service, best rated first', () {
    // pr5 also prunes in Riyadh but is still pending.
    expect(ids('riyadh', ServiceType.pruning), ['pr1', 'pr2']);
    expect(ids('riyadh', ServiceType.treatment), ['pr4', 'pr2']);
    expect(ids('jeddah', ServiceType.periodicCare), ['pr3']);
  });

  test('AC-02 nobody covers the city', () {
    expect(ids('dammam', ServiceType.pruning), isEmpty);
  });

  test('a suspended professional is not shown', () {
    final all = [for (final p in seedProfessionals) p.id == 'pr1' ? p.copyWith(status: PartnerStatus.suspended) : p];
    expect(professionalsFor(all, city: 'riyadh', service: ServiceType.pruning).map((p) => p.id), ['pr2']);
  });
}
