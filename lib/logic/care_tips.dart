import '../models/models.dart';

/// What a care tip is about; the screen picks its icon from this.
enum TipTopic { light, water, heat, indoor, soil, safety }

/// One general care tip. [key] names its text in the strings table.
typedef CareTip = ({TipTopic topic, String key});

/// General care tips worked out from what [plant] needs (its sun, water,
/// place, type and toxicity). They are plain household advice, not quotes
/// from a guide, and the screen says so.
List<CareTip> careTipsFor(Plant plant) => [
      (topic: TipTopic.light, key: 'tip.sun.${plant.sun.name}'),
      (topic: TipTopic.water, key: 'tip.water.${plant.water.name}'),
      if (plant.placements.contains(Placement.outdoor)) (topic: TipTopic.heat, key: 'tip.heat'),
      if (plant.placements.contains(Placement.indoor)) (topic: TipTopic.indoor, key: 'tip.ac'),
      if (plant.category == PlantCategory.succulent) (topic: TipTopic.soil, key: 'tip.drainage'),
      if (plant.toxic) (topic: TipTopic.safety, key: 'tip.toxic'),
    ];
