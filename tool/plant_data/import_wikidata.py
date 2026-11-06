"""Import names and photo credits for Mashtal's plants from Wikidata + Commons.

Sources and licences (see docs/plant-data.md):
  * Wikidata (CC0): item id, Arabic label, English common names.
  * Wikimedia Commons: photo of each species (P18) with its author and
    licence, which the app must show next to the photo.

Care fields (place, sun, water, watering days, toxicity) are NOT imported:
they stay from the RCRC Manual of Riyadh Plants and the ASPCA list.

Usage (from the repo root, needs network access to query.wikidata.org and
commons.wikimedia.org):

    python3 -I tool/plant_data/import_wikidata.py

It reads the scientific names from lib/data/seed/plants_seed.dart, writes the
raw answer to tool/plant_data/wikidata_snapshot.json and regenerates
lib/data/seed/plant_media.g.dart. Review the diff before committing.
Pass --offline to regenerate the Dart file from the saved snapshot only.
"""
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "lib/data/seed/plants_seed.dart"
SNAPSHOT = ROOT / "tool/plant_data/wikidata_snapshot.json"
OUT = ROOT / "lib/data/seed/plant_media.g.dart"
UA = "MashtalPlantImport/1.0 (SWE444 student project; https://github.com/khalednjed-pixel/mashtal)"

# Synonyms Wikidata uses as the accepted taxon name (P225) for a seed name.
SYNONYMS = {
    "Vachellia gerrardii": ["Acacia gerrardii"],
}

LICENCE_URLS = {
    "CC0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "Public domain": "https://commons.wikimedia.org/wiki/Commons:Public_domain",
}


def licence_url(short):
    if short in LICENCE_URLS:
        return LICENCE_URLS[short]
    m = re.match(r"CC (BY(?:-SA)?) (\d\.\d)$", short or "")
    if m:
        return f"https://creativecommons.org/licenses/{m.group(1).lower()}/{m.group(2)}/"
    return None


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 3:
                raise
            time.sleep(int(e.headers.get("Retry-After", "60")))


def seed_plants():
    text = SEED.read_text(encoding="utf8")
    return re.findall(r"id: '(p\d+)'.*?scientificName: '([^']+)'", text)


def query(names):
    lookup = {n: [n] + SYNONYMS.get(n, []) for n in names}
    values = " ".join(json.dumps(v) for vs in lookup.values() for v in vs)
    q = f"""SELECT ?name ?item ?ar ?en ?img WHERE {{
  VALUES ?name {{ {values} }}
  ?item wdt:P225 ?name .
  OPTIONAL {{ ?item rdfs:label ?ar FILTER(lang(?ar)='ar') }}
  OPTIONAL {{ ?item wdt:P1843 ?en FILTER(lang(?en)='en') }}
  OPTIONAL {{ ?item wdt:P18 ?img }}
}}"""
    res = get("https://query.wikidata.org/sparql?format=json&query=" + urllib.parse.quote(q))
    back = {v: n for n, vs in lookup.items() for v in vs}
    plants = {}
    for b in res["results"]["bindings"]:
        n = back[b["name"]["value"]]
        p = plants.setdefault(n, {"wikidata": b["item"]["value"].rsplit("/", 1)[-1], "ar": None, "en": [], "img": None})
        if "ar" in b:
            p["ar"] = b["ar"]["value"]
        if "en" in b and b["en"]["value"] not in p["en"]:
            p["en"].append(b["en"]["value"])
        if "img" in b and not p["img"]:
            p["img"] = urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1])

    files = [p["img"] for p in plants.values() if p["img"]]
    meta = {}
    for i in range(0, len(files), 40):
        titles = "|".join("File:" + f for f in files[i:i + 40])
        r = get("https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo"
                "&iiprop=url|extmetadata&iiurlwidth=500&titles=" + urllib.parse.quote(titles))
        norm = {x["to"]: x["from"] for x in r["query"].get("normalized", [])}
        for pg in r["query"]["pages"].values():
            ii = (pg.get("imageinfo") or [{}])[0]
            em = ii.get("extmetadata", {})
            meta[norm.get(pg["title"], pg["title"])[5:]] = {
                "thumb": ii.get("thumburl"),
                "license": em.get("LicenseShortName", {}).get("value"),
                "artist": em.get("Artist", {}).get("value"),
            }
        time.sleep(1)
    for p in plants.values():
        if p["img"]:
            p["photo"] = meta.get(p["img"]) or meta.get(p["img"].replace("_", " "))
    return {n: plants.get(n) for n in names}


def clean_artist(raw):
    text = html.unescape(re.sub(r"<[^>]+>", "", raw or "")).strip()
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"^(Taken by|by)\s+", "", text, flags=re.I)
    text = re.sub(r"^User:", "", text)
    text = re.sub(r"\s*\(([^)]*)\)$", lambda m: "" if m.group(1) in text[: m.start()] else m.group(0), text)
    # Keep the name only; some authors add a request or a long note.
    text = re.split(r"\s+I'd |\s+Please |\n", text)[0].strip()
    parts = [x.strip() for x in text.split(",")]
    if len(parts) > 3:
        text = parts[0] + " et al."
    return text[:80] or None


def thumb_url(raw):
    """Commons thumbnail on upload.wikimedia.org, 500 px wide, no tracking query."""
    if not raw:
        return None
    u = urllib.parse.urlsplit(raw)
    path = re.sub(r"/\d+px-", "/500px-", u.path)
    return f"https://upload.wikimedia.org{path}"


def dart(s):
    if s is None:
        return "null"
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def write_dart(ids, data):
    lines = [
        "// GENERATED by tool/plant_data/import_wikidata.py from Wikidata (CC0) and",
        "// Wikimedia Commons. Do not edit by hand; re-run the script instead.",
        "// Photos keep their own licences: show [PlantMedia.credit] with each one.",
        "",
        "import '../../models/plant_media.dart';",
        "",
        "const Map<String, PlantMedia> plantMedia = {",
    ]
    for pid, name in ids:
        p = data.get(name)
        if not p:
            continue
        ph = p.get("photo") or {}
        lic = ph.get("license")
        en = [e for e in p["en"] if e][:4]
        lines += [
            f"  '{pid}': PlantMedia(",
            f"    wikidataId: {dart(p['wikidata'])},",
            f"    labelAr: {dart(p['ar'])},",
            f"    namesEn: [{', '.join(dart(e) for e in en)}],",
        ]
        if p.get("img") and ph.get("thumb"):
            lines += [
                f"    photoFile: {dart(p['img'])},",
                f"    photoUrl: {dart(thumb_url(ph['thumb']))},",
                f"    photoAuthor: {dart(clean_artist(ph.get('artist')))},",
                f"    photoLicence: {dart(lic)},",
                f"    photoLicenceUrl: {dart(licence_url(lic))},",
            ]
        lines.append("  ),")
    lines.append("};")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf8")


def main():
    ids = seed_plants()
    if "--offline" in sys.argv:
        data = json.loads(SNAPSHOT.read_text(encoding="utf8"))
    else:
        data = query([n for _, n in ids])
        SNAPSHOT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf8")
    write_dart(ids, data)
    found = [p for p in data.values() if p]
    print(f"{len(found)}/{len(ids)} on Wikidata, {sum(1 for p in found if p.get('photo'))} with a credited photo")
    print("missing:", [n for _, n in ids if not data.get(n)])


if __name__ == "__main__":
    main()
