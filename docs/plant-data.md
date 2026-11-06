# Plant data sources and licences (Sprint 2)

Mashtal combines several free sources. Each field comes from the source that is best for it, and the scientific name links them.

| Field | Source | Licence | Where in the code |
|---|---|---|---|
| Place, sun, water, watering days | RCRC *Manual of Riyadh Plants* (TF-06) | Cited, not copied in bulk | `lib/data/seed/plants_seed.dart` |
| Toxic to children or pets | ASPCA toxic plants list (OD-10) | Cited | `plants_seed.dart` |
| Arabic and English names, plant type, description | Mashtal team | Ours | `plants_seed.dart` |
| Wikidata id, extra Arabic and English names | [Wikidata](https://www.wikidata.org) | CC0, no conditions | `lib/data/seed/plant_media.g.dart` |
| Photo, its author and licence | [Wikimedia Commons](https://commons.wikimedia.org) | Per photo: CC BY, CC BY-SA, CC0 or public domain | `plant_media.g.dart` |

Care data is never taken from Wikidata: the suitability score (US-09) depends on it, and only the RCRC guide is written for Riyadh.

## What the app does with it

- **Photos.** Plant photos come from the imported Commons file, so the app no longer looks each species up on Wikipedia. Under the photo on the plant page the app shows the author and the licence, linked to the Commons file page and the licence text, as CC BY and CC BY-SA require. Nursery photos still come first.
- **Search.** Wikidata's Arabic label and English common names are extra search terms (for example "دفلى" or "flamboyant"). Wikidata's Arabic labels are often formal botanical names (غاف رمادي, ذلب ثلاثي الأحزمة), so the app keeps showing its own Arabic names, and its own names still rank first.
- **Credits.** Account → *Data and photo sources* lists all the sources.

## Coverage (live run, 4 Nov 2026)

35 of the 37 plants are on Wikidata, and all 35 have a photo with a known licence. Two are missing and fall back to the Wikipedia lookup:

- *Vachellia gerrardii* (الطلح): the importer also tries the synonym *Acacia gerrardii*.
- *Hibiscus rosa-sinensis* (الهبسكس): not matched by its taxon name; add the Wikidata id by hand if needed.

## Updating

```bash
python3 -I tool/plant_data/import_wikidata.py          # needs query.wikidata.org and commons.wikimedia.org
python3 -I tool/plant_data/import_wikidata.py --offline # rebuild the Dart file from the saved snapshot
```

The script reads the scientific names from `plants_seed.dart`, saves the raw answer in `tool/plant_data/wikidata_snapshot.json` and regenerates `plant_media.g.dart`. Review the diff before committing; in particular check that each new photo shows the plant and not only a flower or a herbarium sheet. query.wikidata.org allows about one query a minute from shared networks, so run it rarely.

When the app moves to Firestore, these fields go into the same `plants/{id}` documents (`wikidataId`, `photoUrl`, `photoAuthor`, `photoLicence`).

## Not used

- **Kew WCVP** (CC BY 4.0) for a "native to Saudi Arabia" badge: optional, not added in Sprint 2.
- **Perenual, Trefle, PFAF:** paid, unmaintained or not licensed for reuse.
- **Kaggle plant datasets:** licences are set by the uploader and often unclear. Labelled photo sets may help Ask Mashtal later (TF-10).
