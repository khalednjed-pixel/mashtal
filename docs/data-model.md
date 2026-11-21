# Mashtal data model (Sprint 2)

The app talks to its backend through two interfaces in `lib/data/repositories.dart`:
`AuthRepository` and `MarketRepository`.

`LocalBackend` (`lib/data/local_backend.dart`) implements both and checks the same permissions as `firebase/firestore.rules`. Offline it keeps the data on the device. Since TF-03 (Sprint 3) it is given `FirebaseServices` (`lib/data/firebase_services.dart`): accounts go to Firebase Authentication and all collections below live in Firestore project `mashtal-1`, shared by every device. The screens did not change.

## Firestore collections

| Collection | Document fields | Who can read | Who can write |
|---|---|---|---|
| `users/{uid}` | phone (+966…), name, city, role (`customer`, `nursery`, `professional`, `admin`), partnerId?, createdAt | the user, admin | the user creates their own profile and may edit name and city. The role must be `customer`, or exactly what `partnerAccounts` gives the user's number |
| `partnerAccounts/{+966…}` | role, partnerId? | that number's user, admin | admin. Written by the app when the admin creates, edits or deletes a nursery or professional. The first admin is added by hand |
| `meta/seed` | at | everyone | admin; marks that the demo data was uploaded |
| `plants/{id}` | nameAr, nameEn, scientificName, category, placements[], sun, water, wateringEveryDays, toxic, descriptionAr/En, source, guideBacked, guideSection?, addedBy?, wikiTitle?, photo? | everyone | admin. A nursery may add a plant missing from the list (`guideBacked: false`, `addedBy` = its id) and delete the plants it added |
| `nurseries/{id}` | nameAr, nameEn, city, district, phone, hours, status (`pending`, `verified`, `suspended`), rating, ratingCount | everyone if verified, otherwise the admin and the nursery itself | admin. New nurseries must start as `pending` |
| `professionals/{id}` | nameAr, nameEn, cities[], services[], phone, status, rating, jobsDone | same as nurseries | admin. The professional may change only their own services and cities |
| `listings/{id}` | nurseryId, plantId, price (SAR), quantity, hidden, public, photo? | everyone if `public`, plus the admin and the owning nursery | the owning nursery, which can also delete it. `public` must equal `!hidden && nursery verified` |
| `reservations/{id}` | customerId, customerName, customerPhone, nurseryId, items[] (listingId, plantId, quantity, price), createdAt, status (`pending`, `accepted`, `rejected`, `pickedUp`), acceptedAt?, rejectReason? (`outOfStock`, `other`) | the customer, that nursery, admin | a customer creates their own, one per nursery, always `pending` (US-16). That nursery accepts it (sets `acceptedAt`; held 48 hours from then, OD-01) or rejects it with a reason, only while pending (US-17) |
| `garden/{id}` | ownerId, plantId, addedAt, source (`pickup`, `manual`), quantity, reservationId?, nurseryId?, lastWateredAt? | the owner | the owner adds plants bought elsewhere (`manual`), records waterings and removes plants (US-21) |
| `priceRanges/{service}` | min, max (SAR) | everyone | admin, with min < max |
| `plantEdits/{id}` | plantId, field, oldValue, newValue, editorId, editorName, at | admin | admin creates entries as themselves; entries can never be changed or deleted (US-14) |

## Why `listings.public` exists

Firestore rules cannot join documents inside a query. So each listing stores whether customers may see it: it is not hidden and its nursery is verified.

The rules reject any write where `public` does not match those two facts. When the admin changes a nursery's status, the admin's client (later, a Cloud Function) updates `public` on that nursery's listings.

## Seed data

Seed data lives in `lib/data/seed/`:

- `plants_seed.dart`: 37 species. 33 outdoor species are from the RCRC *Manual of Riyadh Plants*. 4 common houseplants are labelled "not guide-backed" (OD-03). Toxicity follows the ASPCA list (OD-10).
- `seed_data.dart`: invented demo data, namely 5 nurseries (one pending), 5 professionals (one pending), 43 listings, 4 price ranges and 5 demo accounts.

## Photos

Guide plants show a photo from Wikipedia, loaded in the browser from the article named by the plant's scientific name (or `wikiTitle`), with a credit link. A nursery can add its own photo to a listing or to a plant it added. The photo is a small base64 JPEG kept in the document's `photo` field. Cloud Storage would need the paid Blaze plan, so it is not used.

## Sign-in

The code is still shown on screen (no SMS). After a correct code the app signs in to a Firebase Email/Password account named after the number, e.g. `966500000001@phone.mashtal.app`, creating it on the first visit. The rules read the number from that email. This does not truly prove the user owns the phone; it was chosen so the demo needs no paid SMS.
