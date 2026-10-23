import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/text_match.dart';

void main() {
  group('normalizeForSearch', () {
    test('ignores alef forms, taa marbuta and diacritics', () {
      expect(normalizeForSearch('أَثْل'), normalizeForSearch('اثل'));
      expect(normalizeForSearch('الروضة'), normalizeForSearch('روضه'));
    });

    test('treats the definite article as optional', () {
      expect(matchesQuery('سدر', ['السدر']), isTrue);
      expect(matchesQuery('السدر', ['سدر']), isTrue);
    });

    test('is case-insensitive for English', () {
      expect(matchesQuery('DATE palm', ['Date palm']), isTrue);
    });
  });

  test('every query word must match', () {
    expect(matchesQuery('date palm', ['Date palm']), isTrue);
    expect(matchesQuery('date tree', ['Date palm']), isFalse);
  });

  test('exact matches rank before partial ones', () {
    expect(matchRank('غاف', ['الغاف']), 0);
    expect(matchRank('date', ['Date palm']), 1);
    expect(matchRank('غاف', ['الأغاف']), 2);
  });

  test('empty query matches everything', () {
    expect(matchesQuery('  ', ['anything']), isTrue);
  });
}
