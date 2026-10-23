import '../../models/models.dart';

/// Synthetic partner data for development and the demo (TF-07, A-03).
/// Names are invented; no real businesses are represented.

const List<Nursery> seedNurseries = [
  Nursery(
    id: 'n1', nameAr: 'مشتل الروضة', nameEn: 'Al Rawdah Nursery', city: 'riyadh', district: 'الروضة',
    phone: '0500000101', hours: '8:00–22:00', status: PartnerStatus.verified, rating: 4.6, ratingCount: 38,
  ),
  Nursery(
    id: 'n2', nameAr: 'مشاتل النخيل الخضراء', nameEn: 'Green Palms Nurseries', city: 'riyadh', district: 'الملقا',
    phone: '0500000102', hours: '7:00–21:00', status: PartnerStatus.verified, rating: 4.3, ratingCount: 21,
  ),
  Nursery(
    id: 'n3', nameAr: 'مشتل الياسمين', nameEn: 'Yasmin Nursery', city: 'riyadh', district: 'السويدي',
    phone: '0500000103', hours: '9:00–23:00', status: PartnerStatus.verified, rating: 4.8, ratingCount: 54,
  ),
  Nursery(
    id: 'n4', nameAr: 'مشتل الواحة', nameEn: 'Oasis Nursery', city: 'jeddah', district: 'الروضة',
    phone: '0500000104', hours: '8:00–22:00', status: PartnerStatus.verified, rating: 4.1, ratingCount: 12,
  ),
  Nursery(
    id: 'n5', nameAr: 'مشتل الفجر', nameEn: 'Al Fajr Nursery', city: 'riyadh', district: 'النرجس',
    phone: '0500000105', hours: '8:00–20:00', status: PartnerStatus.pending,
  ),
];

const List<Professional> seedProfessionals = [
  Professional(
    id: 'pr1', nameAr: 'عبدالله الزراعي', nameEn: 'Abdullah Alzarai', cities: ['riyadh'],
    services: {ServiceType.planting, ServiceType.pruning, ServiceType.periodicCare},
    phone: '0500000201', status: PartnerStatus.verified, rating: 4.7, jobsDone: 41,
  ),
  Professional(
    id: 'pr2', nameAr: 'مؤسسة الظل الأخضر', nameEn: 'Green Shade Services', cities: ['riyadh'],
    services: {ServiceType.treatment, ServiceType.pruning},
    phone: '0500000202', status: PartnerStatus.verified, rating: 4.4, jobsDone: 27,
  ),
  Professional(
    id: 'pr3', nameAr: 'سعد للحدائق', nameEn: 'Saad Gardens', cities: ['riyadh', 'jeddah'],
    services: {ServiceType.periodicCare, ServiceType.planting},
    phone: '0500000203', status: PartnerStatus.verified, rating: 4.2, jobsDone: 15,
  ),
  Professional(
    id: 'pr4', nameAr: 'خبير النخيل', nameEn: 'Palm Expert', cities: ['riyadh'],
    services: {ServiceType.treatment},
    phone: '0500000204', status: PartnerStatus.verified, rating: 4.9, jobsDone: 63,
  ),
  Professional(
    id: 'pr5', nameAr: 'تنسيق الربيع', nameEn: 'Spring Landscaping', cities: ['riyadh'],
    services: {ServiceType.planting, ServiceType.pruning},
    phone: '0500000205', status: PartnerStatus.pending,
  ),
];

const List<PriceRange> seedPriceRanges = [
  PriceRange(service: ServiceType.planting, min: 100, max: 300),
  PriceRange(service: ServiceType.pruning, min: 150, max: 400),
  PriceRange(service: ServiceType.periodicCare, min: 200, max: 600),
  PriceRange(service: ServiceType.treatment, min: 250, max: 800),
];

/// Demo accounts. Any other number can register as a new customer.
const List<AppUser> seedUsers = [
  AppUser(id: 'u-admin', phone: '0500000001', name: 'مدير مشتل', city: 'riyadh', role: Role.admin),
  AppUser(id: 'u-n1', phone: '0500000002', name: 'مشتل الروضة', city: 'riyadh', role: Role.nursery, partnerId: 'n1'),
  AppUser(id: 'u-n5', phone: '0500000003', name: 'مشتل الفجر', city: 'riyadh', role: Role.nursery, partnerId: 'n5'),
  AppUser(id: 'u-pr1', phone: '0500000004', name: 'عبدالله الزراعي', city: 'riyadh', role: Role.professional, partnerId: 'pr1'),
  AppUser(id: 'u-c1', phone: '0500000005', name: 'سارة', city: 'riyadh', role: Role.customer),
];

/// (nursery, plant, price SAR, quantity, hidden)
const List<(String, String, double, int, bool)> _listingRows = [
  ('n1', 'p01', 180, 12, false),
  ('n1', 'p03', 220, 8, false),
  ('n1', 'p04', 450, 5, false),
  ('n1', 'p12', 35, 40, false),
  ('n1', 'p13', 45, 25, false),
  ('n1', 'p16', 30, 60, false),
  ('n1', 'p23', 25, 0, false),
  ('n1', 'p26', 20, 30, false),
  ('n1', 'p32', 15, 18, false),
  ('n1', 'p37', 28, 14, false),
  ('n2', 'p04', 420, 9, false),
  ('n2', 'p11', 380, 6, false),
  ('n2', 'p02', 260, 4, false),
  ('n2', 'p05', 150, 10, false),
  ('n2', 'p10', 240, 3, false),
  ('n2', 'p14', 40, 22, false),
  ('n2', 'p15', 35, 30, false),
  ('n2', 'p29', 18, 50, false),
  ('n2', 'p30', 12, 200, false),
  ('n3', 'p01', 195, 7, false),
  ('n3', 'p07', 210, 5, false),
  ('n3', 'p08', 160, 6, false),
  ('n3', 'p09', 230, 4, false),
  ('n3', 'p17', 22, 35, false),
  ('n3', 'p22', 38, 20, false),
  ('n3', 'p23', 27, 45, false),
  ('n3', 'p24', 33, 28, false),
  ('n3', 'p25', 55, 9, false),
  ('n3', 'p28', 26, 16, false),
  ('n3', 'p31', 14, 80, false),
  ('n3', 'p34', 35, 20, false),
  ('n3', 'p35', 45, 15, false),
  ('n3', 'p36', 60, 0, false),
  ('n3', 'p19', 30, 10, true),
  ('n4', 'p04', 400, 8, false),
  ('n4', 'p16', 28, 40, false),
  ('n4', 'p24', 30, 20, false),
  ('n4', 'p26', 18, 25, false),
  ('n4', 'p27', 70, 6, false),
  ('n4', 'p35', 42, 12, false),
  ('n5', 'p01', 170, 10, false),
  ('n5', 'p06', 240, 5, false),
  ('n5', 'p20', 40, 12, false),
];

final List<Listing> seedListings = [
  for (final (i, r) in _listingRows.indexed)
    Listing(id: 'l${i + 1}', nurseryId: r.$1, plantId: r.$2, price: r.$3, quantity: r.$4, hidden: r.$5),
];
