import '../models/models.dart';

/// US-24: the professionals a customer may choose for [service] in [city]:
/// verified only, covering that city and offering that service, best rated
/// first (then the most jobs done).
List<Professional> professionalsFor(Iterable<Professional> all, {required String city, required ServiceType service}) =>
    all
        .where((p) => p.status == PartnerStatus.verified && p.cities.contains(city) && p.services.contains(service))
        .toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : b.jobsDone.compareTo(a.jobsDone);
      });
