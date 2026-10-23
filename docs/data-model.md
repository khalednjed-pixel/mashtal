# Mashtal data model (Sprint 1)

The app talks to its backend through two interfaces in `lib/data/repositories.dart`:
`AuthRepository` and `MarketRepository`.

**Sprint 1** ships `LocalBackend` (`lib/data/local_backend.dart`), which keeps the data on the device (browser storage on the web build). This lets the app run and be tested without a Firebase project. It checks the same permissions as `firebase/firestore.rules`.

When the team's Firebase project exists, a `FirebaseBackend` implementing the same two interfaces replaces it. The screens do not change.

## Firestore collections

| Collection | Document fields | Who can read | Who can write |
|---|---|---|---|
| `users/{uid}` | phone, name, city, role (`customer`, `nursery`, `professional`, `admin`), partnerId? | the user, admin | the user creates their own **customer** profile and may edit name and city. Only the admin sets role and partnerId |
| `plants/{id}` | nameAr, nameEn, scientificName, category, placements[], sun, water, wateringEveryDays, toxic, descriptionAr/En, source, guideBacked, addedBy?, photoUrl? | everyone | admin. A nursery may add a plant missing from the list (`guideBacked: false`, `addedBy` = its id) and delete the plants it added |
| `nurseries/{id}` | nameAr, nameEn, city, district, phone, hours, status (`pending`, `verified`, `suspended`), rating, ratingCount | everyone if verified, otherwise the admin and the nursery itself | admin. New nurseries must start as `pending` |
| `professionals/{id}` | nameAr, nameEn, cities[], services[], phone, status, rating, jobsDone | same as nurseries | admin. The professional may change only their own services and cities |
| `listings/{id}` | nurseryId, plantId, price (SAR), quantity, hidden, public, photoUrl? | everyone if `public`, plus the admin and the owning nursery | the owning nursery, which can also delete it. `public` must equal `!hidden && nursery verified` |
| `priceRanges/{service}` | min, max (SAR) | everyone | admin, with min < max |

## Why `listings.public` exists

Firestore rules cannot join documents inside a query. So each listing stores whether customers may see it: it is not hidden and its nursery is verified.

The rules reject any write where `public` does not match those two facts. When the admin changes a nursery's status, the admin's client (later, a Cloud Function) updates `public` on that nursery's listings.

## Seed data

Seed data lives in `lib/data/seed/`:

- `plants_seed.dart`: 37 species. 33 outdoor species are from the RCRC *Manual of Riyadh Plants*. 4 common houseplants are labelled "not guide-backed" (OD-03). Toxicity follows the ASPCA list (OD-10).
- `seed_data.dart`: invented demo data, namely 5 nurseries (one pending), 5 professionals (one pending), 43 listings, 4 price ranges and 5 demo accounts.

## Photos

Guide plants show a photo from Wikipedia, loaded in the browser from the article named by the plant's scientific name (or `wikiTitle`), with a credit link. A nursery can add its own photo to a listing or to a plant it added. The demo backend keeps those photos as small base64 JPEGs in the browser; with Firebase they move to Cloud Storage and the document keeps `photoUrl`.
