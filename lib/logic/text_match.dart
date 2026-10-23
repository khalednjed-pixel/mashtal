/// Normalises Arabic and English text so searches ignore diacritics, the
/// different forms of alef, taa marbuta and letter case (US-05).
String normalizeForSearch(String input) {
  var s = input.trim().toLowerCase();
  // Arabic diacritics (tashkeel) and tatweel.
  s = s.replaceAll(RegExp('[ً-ْٰـ]'), '');
  s = s
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  // Treat the definite article as optional: "السدر" matches "سدر".
  s = s.replaceAllMapped(RegExp(r'(^|\s)ال'), (m) => m[1]!);
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

/// True when every word of [query] appears in at least one of [fields].
bool matchesQuery(String query, Iterable<String> fields) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  final haystack = fields.map(normalizeForSearch).join(' ');
  return q.split(' ').every(haystack.contains);
}

/// Lower is better: 0 when a field equals the query, 1 when a word in a field
/// starts with it, 2 for any other match.
int matchRank(String query, Iterable<String> fields) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return 2;
  final normalized = fields.map(normalizeForSearch).toList();
  if (normalized.contains(q)) return 0;
  if (normalized.any((f) => f.split(' ').any((w) => w.startsWith(q)))) return 1;
  return 2;
}
