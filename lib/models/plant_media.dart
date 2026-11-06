/// Names and a photo for a species, imported from Wikidata and Wikimedia
/// Commons by tool/plant_data/import_wikidata.py (see docs/plant-data.md).
///
/// Wikidata is CC0. Each Commons photo keeps its own licence, so the app shows
/// [credit] and links to the licence wherever the photo appears.
class PlantMedia {
  const PlantMedia({
    required this.wikidataId,
    this.labelAr,
    this.namesEn = const [],
    this.photoFile,
    this.photoUrl,
    this.photoAuthor,
    this.photoLicence,
    this.photoLicenceUrl,
  });

  /// Wikidata item, e.g. Q1136117.
  final String wikidataId;

  /// Arabic label on Wikidata. Often the formal botanical name, so it is used
  /// only as an extra search term, never instead of the app's own Arabic name.
  final String? labelAr;

  /// English common names on Wikidata, used as extra search terms.
  final List<String> namesEn;

  /// File name on Wikimedia Commons.
  final String? photoFile;
  final String? photoUrl;
  final String? photoAuthor;

  /// Short licence name, e.g. "CC BY-SA 4.0", "CC0", "Public domain".
  final String? photoLicence;
  final String? photoLicenceUrl;

  bool get hasPhoto => photoUrl != null;

  String get wikidataUrl => 'https://www.wikidata.org/wiki/$wikidataId';

  String? get photoPageUrl =>
      photoFile == null ? null : 'https://commons.wikimedia.org/wiki/File:${Uri.encodeComponent(photoFile!.replaceAll(' ', '_'))}';

  /// "Author, CC BY-SA 4.0, Wikimedia Commons" (TASL attribution).
  String get credit => [photoAuthor, photoLicence, 'Wikimedia Commons'].whereType<String>().join(' · ');

  /// Search terms besides the app's own names.
  List<String> get aliases => [?labelAr, ...namesEn];
}
