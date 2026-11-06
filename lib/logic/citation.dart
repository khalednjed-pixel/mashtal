import '../models/models.dart';

/// Where a recommendation comes from (US-10, NFR-01).
class GuideCitation {
  const GuideCitation({
    required this.guide,
    required this.publisher,
    required this.edition,
    required this.section,
    required this.guideAr,
    required this.publisherAr,
    required this.editionAr,
    required this.sectionAr,
  });

  final String guide;
  final String publisher;
  final String edition;
  final String section;

  /// Arabic wording of the same citation, so the Arabic UI shows no English
  /// (QA BUG-4). A section copied from the guide stays as written there.
  final String guideAr;
  final String publisherAr;
  final String editionAr;
  final String sectionAr;

  String guideIn(String lang) => lang == 'ar' ? guideAr : guide;
  String publisherIn(String lang) => lang == 'ar' ? publisherAr : publisher;
  String editionIn(String lang) => lang == 'ar' ? editionAr : edition;
  String sectionIn(String lang) => lang == 'ar' ? sectionAr : section;
}

const _rcrcGuide = 'Manual of Riyadh Plants';
const _rcrcPublisher = 'Royal Commission for Riyadh City (RCRC)';
const _rcrcEdition = 'English version';
const _rcrcGuideAr = 'دليل نباتات الرياض';
const _rcrcPublisherAr = 'الهيئة الملكية لمدينة الرياض';
const _rcrcEditionAr = 'النسخة الإنجليزية';

/// Section by plant type, used until TF-06 records the exact section of
/// each entry in [Plant.guideSection].
String _sectionFor(PlantCategory c) => switch (c) {
      PlantCategory.tree => 'Trees',
      PlantCategory.palm => 'Palms',
      PlantCategory.shrub => 'Shrubs',
      PlantCategory.climber => 'Climbers',
      PlantCategory.succulent => 'Succulents',
      PlantCategory.groundcover => 'Groundcovers',
      PlantCategory.grass => 'Ornamental grasses',
      PlantCategory.herb => 'Herbs',
      PlantCategory.houseplant => 'Houseplants',
    };

String _sectionArFor(PlantCategory c) => switch (c) {
      PlantCategory.tree => 'الأشجار',
      PlantCategory.palm => 'النخيل',
      PlantCategory.shrub => 'الشجيرات',
      PlantCategory.climber => 'المتسلقات',
      PlantCategory.succulent => 'النباتات العصارية',
      PlantCategory.groundcover => 'المغطيات الأرضية',
      PlantCategory.grass => 'أعشاب الزينة',
      PlantCategory.herb => 'الأعشاب',
      PlantCategory.houseplant => 'النباتات الداخلية',
    };

/// The guide citation of a guide-backed plant, or null for plants outside
/// the official guide, which the UI labels instead (US-11, OD-03).
GuideCitation? citationFor(Plant p) {
  if (!p.guideBacked || p.isCustom) return null;
  return GuideCitation(
    guide: _rcrcGuide,
    publisher: _rcrcPublisher,
    edition: _rcrcEdition,
    section: p.guideSection ?? _sectionFor(p.category),
    guideAr: _rcrcGuideAr,
    publisherAr: _rcrcPublisherAr,
    editionAr: _rcrcEditionAr,
    sectionAr: p.guideSection ?? _sectionArFor(p.category),
  );
}
