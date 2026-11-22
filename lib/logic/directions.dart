import '../models/models.dart';

/// Map links for a nursery (US-18). With coordinates the map app starts
/// directions to that point; without them it searches for the nursery by
/// name and district.
Uri directionsTo(Nursery n) {
  final lat = n.lat, lng = n.lng;
  if (lat != null && lng != null) {
    return Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lng'});
  }
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '${n.nameEn}, ${n.district}, ${n.city}'});
}

/// Reads "24.7136, 46.6753" or a pasted Google Maps link (…@24.71,46.67,15z
/// or …?q=24.71,46.67) into a latitude and longitude. Null if neither is
/// found or the point is not on Earth.
(double, double)? parseLocation(String input) {
  final m = RegExp(r'(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)').firstMatch(input);
  if (m == null) return null;
  final lat = double.parse(m[1]!), lng = double.parse(m[2]!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat, lng);
}
