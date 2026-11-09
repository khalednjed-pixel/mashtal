import '../models/models.dart';
import 'catalog_search.dart';

/// The shop filters per account, guests included, kept for the whole visit so
/// the plant page can use the same city the shopper picked.
final Map<String, SearchFilters> savedShopFilters = {};

/// The current shop filters for [user]. A signed-in user starts filtered to
/// their own city and can change it (feedback 3).
SearchFilters shopFiltersFor(AppUser? user) =>
    savedShopFilters.putIfAbsent(user?.id ?? 'guest', () => SearchFilters(city: user?.city));

void setShopFilters(AppUser? user, SearchFilters filters) => savedShopFilters[user?.id ?? 'guest'] = filters;

/// The city whose nurseries come first on a plant page: the shop filter city
/// when one is set (it wins over the account city), else the account city.
String? preferredCity(AppUser? user) => shopFiltersFor(user).city ?? user?.city;
