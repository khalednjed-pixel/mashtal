import '../models/models.dart';

/// Who an entry came from, for the "source" label (US-22 AC-01).
enum HistorySource { you, nursery, askMashtal, professional }

class HistoryItem {
  const HistoryItem({required this.kind, required this.at, required this.source, this.sourceName, this.text, this.photo});
  final HistoryKind kind;
  final DateTime at;
  final HistorySource source;

  /// The nursery's or professional's name.
  final String? sourceName;
  final String? text;

  /// A growth photo, base64 JPEG.
  final String? photo;
}

/// A garden plant's history, newest first: how it arrived (from the plant
/// itself) followed by its stored entries.
List<HistoryItem> plantStory(GardenPlant g, List<HistoryEntry> entries, {Nursery? nursery, String lang = 'ar'}) {
  final items = [
    if (g.source == GardenSource.pickup)
      HistoryItem(kind: HistoryKind.pickedUp, at: g.addedAt, source: HistorySource.nursery, sourceName: nursery?.name(lang))
    else
      HistoryItem(kind: HistoryKind.added, at: g.addedAt, source: HistorySource.you),
    for (final e in entries.where((e) => e.gardenPlantId == g.id))
      HistoryItem(
        kind: e.kind,
        at: e.at,
        text: e.text,
        photo: e.photo,
        sourceName: e.sourceName,
        source: switch (e.kind) {
          HistoryKind.check => HistorySource.askMashtal,
          HistoryKind.proFeedback => HistorySource.professional,
          HistoryKind.pickedUp => HistorySource.nursery,
          _ => HistorySource.you,
        },
      ),
  ];
  // Stable: entries at the same moment keep their order, newest first.
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byTime = b.$2.at.compareTo(a.$2.at);
      return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
    });
  return [for (final (_, i) in indexed) i];
}
