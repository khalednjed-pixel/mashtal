import '../models/models.dart';

/// Where a recommendation comes from (US-10, NFR-01).
class GuideCitation {
  const GuideCitation({required this.guide, required this.publisher, required this.edition, required this.section});

  final String guide;
  final String publisher;
  final String edition;
  final String section;
}

const _rcrcGuide = 'Manual of Riyadh Plants';
const _rcrcPublisher = 'Royal Commission for Riyadh City (RCRC)';
const _rcrcEdition = 'English version';

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

/// The guide citation of a guide-backed plant, or null for plants outside
/// the official guide, which the UI labels instead (US-11, OD-03).
GuideCitation? citationFor(Plant p) {
  if (!p.guideBacked || p.isCustom) return null;
  return GuideCitation(
    guide: _rcrcGuide,
    publisher: _rcrcPublisher,
    edition: _rcrcEdition,
    section: p.guideSection ?? _sectionFor(p.category),
  );
}
