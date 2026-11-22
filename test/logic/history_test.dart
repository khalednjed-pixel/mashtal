import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/history.dart';
import 'package:mashtal/models/models.dart';

/// US-22 AC-01: a plant's history, newest first, with date and source.
void main() {
  final day = DateTime(2026, 11, 1);
  DateTime at(int d) => day.add(Duration(days: d));
  HistoryEntry entry(String id, HistoryKind kind, int d, {String? text, String? from}) =>
      HistoryEntry(id: id, ownerId: 'u-c1', gardenPlantId: 'g1', kind: kind, at: at(d), text: text, sourceName: from);

  final picked = GardenPlant(
    id: 'g1', ownerId: 'u-c1', plantId: 'p04', addedAt: at(0), source: GardenSource.pickup, reservationId: 'r1', nurseryId: 'n1',
  );

  test('Ask Mashtal results and professional feedback are listed newest first with their source', () {
    final story = plantStory(
      picked,
      [
        entry('a', HistoryKind.check, 3, text: 'Too much water'),
        entry('b', HistoryKind.proFeedback, 9, text: 'Pruned the dry fronds', from: 'Abdullah Alzarai'),
        entry('c', HistoryKind.watered, 5),
        entry('x', HistoryKind.note, 7),
      ],
      nursery: seedNurseries.first,
      lang: 'en',
    );
    expect(story.map((i) => i.kind), [HistoryKind.proFeedback, HistoryKind.note, HistoryKind.watered, HistoryKind.check, HistoryKind.pickedUp]);
    expect(story.first.source, HistorySource.professional);
    expect(story.first.sourceName, 'Abdullah Alzarai');
    expect(story[3].source, HistorySource.askMashtal);
    expect(story[3].text, 'Too much water');
    expect(story.last.sourceName, 'Al Rawdah Nursery');
    expect(story.last.at, at(0));
  });

  test('a plant added by hand starts with "added", from you', () {
    final manual = GardenPlant(id: 'g2', ownerId: 'u-c1', plantId: 'p04', addedAt: at(0), source: GardenSource.manual);
    final story = plantStory(manual, [entry('a', HistoryKind.note, 1)]);
    expect(story, hasLength(1 + 0), reason: 'the note belongs to another plant');
    expect(story.single.kind, HistoryKind.added);
    expect(story.single.source, HistorySource.you);
  });
}
