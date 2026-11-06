# مشتل · Mashtal

**Know what will grow. Buy it. Keep it alive.**

SWE 444 project, King Saud University, Fall 2026. Team: Faisal Alamer, Fares Alohali, Khaled Alnujaidi, Ghali Alkhamis.

Mashtal is an Arabic-first app for households in Saudi Arabia. Customers find plants that suit their place, buy them from verified nurseries, and book verified professionals to care for them.

- **Live demo:** https://khalednjed-pixel.github.io/mashtal/
- **Sprint board:** https://trello.com/b/RwS1VNta/mashtal-swe-444-sprint-board

## Sprint 1: Foundation (US-01 to US-06)

| Story | What works |
|---|---|
| US-01 Guest | Buy Plants, search and plant pages work without an account. Reserving or opening My Garden asks you to sign in and brings you back to the same page, with your cart kept. |
| US-02 Phone sign-up | Saudi mobile number (05XXXXXXXX) plus a 6-digit code, then name and city for new numbers. Wrong codes show an Arabic error. A new code can be requested after 60 seconds. |
| US-03 Verification | The admin adds nurseries and professionals as *pending* and verifies or suspends them. Customers never see unverified partners or their listings. |
| US-04 Role navigation | Customer, nursery, professional and admin each get their own tabs. Opening another role's page sends you home with an "access denied" message. |
| US-05 Search | Arabic or English plant names (ignoring hamza and diacritics) and nursery names, with filters for indoor/outdoor, sun, water, price and city. Plants are listed first, then nurseries. |
| US-06 Nursery listings | A nursery adds plants from the plant list with price and quantity, edits them, or hides them. Quantity 0 shows as "not available". |

Arabic (right-to-left) is the default. English is one tap away.

### Changes after the Sprint 1 review

- The language button names the language you switch to, and every text in the app can be selected and copied.
- Max price is a slider with stops (10, 15, 25, 50, 100, 250, 500, 1000, any) plus a field to type any price. Signed-in customers start with their own city as the filter.
- Phone numbers are limited to 10 digits. Each account has its own cart.
- The admin can open Buy Plants, edit or delete nurseries and professionals, and edit the service price ranges.
- A nursery can delete listings, add its own photo, and add a plant that is missing from the list (labelled as added by a nursery). Everything that can be added can be deleted.
- Plants show real photos from Wikipedia with a credit link.
- The professional page shows status, rating and jobs, and lets the professional choose services (with the admin's price range) and cities.
- Account → *Edit my details* changes your name and city.

## Sprint 2: Choose (US-07 to US-14)

| Story | What works |
|---|---|
| US-07 Questions | *Choose a plant* asks one plain question per screen with a progress bar: city, place, window or sun, room, watering, children or pets. The window question is only asked inside the house. |
| US-08 Skip | "Skip" on any question opens Buy Plants with no filter. |
| US-09 Ranking | Up to 10 plants with a suitability percentage and a per-factor breakdown. Toxic plants are never shown when there are children or pets. Rules, not AI: see [docs/suitability.md](docs/suitability.md). |
| US-10 Citation | Every guide-backed result cites the RCRC guide, edition and section; "Why this score?" lists the plant values next to your answers. |
| US-11 Not covered | Cities other than Riyadh get "not covered yet". If nothing fits, the app names the answer that ruled out most plants. |
| US-12 Compare nurseries | Tapping a result lists the verified nurseries that have it, cheapest first, with rating and city. |
| US-13 Price ranges | The admin sets a minimum and maximum per service (minimum below maximum), shown on the admin's professionals list. The customer list (US-24) and bookings that keep the agreed price (AC-02) come with the booking stories. |
| US-14 Plant data | Admin tab *Plant data* edits place, sun, water, watering days and toxicity. Results use the change at once, and each change is logged with editor, time and old value. |

NFR-01 and NFR-02 are checked over 30 labelled scenarios in `test/logic/nfr_scenarios_test.dart` (29 of 30 have the expected plant in the top 3).

### Plant data from Wikidata and Wikimedia Commons

35 of the 37 plants are linked to Wikidata (CC0). Their photos come from Wikimedia Commons, and the plant page credits each photo's author and licence. Wikidata's Arabic and English names work as extra search terms. Care data still comes from the RCRC guide. See [docs/plant-data.md](docs/plant-data.md).

### Fixes from the QA session (2 Nov 2026)

- The cart can no longer hold more than the nursery has; the + button stops at the stock, and lines shrink or disappear when a nursery lowers its stock (BUG-1).
- The cart buttons and the search field have names for screen readers (BUG-2, BUG-3).
- The Arabic plant page and the citation show the source in Arabic (BUG-4).
- Sold-out listings show as "not available" on both the plant and the nursery page, and the shop counts only nurseries that have the plant (BUG-5).
- A pasted +966 number is turned into 05… instead of being cut off (BUG-7).
- BUG-6 (empty console errors) did not reproduce as a Dart error in a profile build; the only errors were photos that failed to download, which the app replaces with an icon.

## Try it

Open the live demo and use a demo account. **There is no real SMS**: the code is shown on screen.

| Number | Role |
|---|---|
| 0500000001 | Admin |
| 0500000002 | Nursery (verified: Al Rawdah) |
| 0500000003 | Nursery (pending: Al Fajr) |
| 0500000004 | Professional |
| 0500000005 | Customer |

Any other 05 number registers as a new customer. *Account → Reset demo data* restores the seed data.

## How it is built

- **Flutter** (Android and web from one codebase), with `provider` for state, `go_router` for navigation and the route guards, and the Tajawal font.
- **Backend:** the app runs on `LocalBackend`, which keeps data on the device, because the team's Firebase project is not set up yet. The screens use the `AuthRepository` and `MarketRepository` interfaces, so Firebase can replace it without changing them. See [docs/data-model.md](docs/data-model.md).
- **Security:** `firebase/firestore.rules` enforces roles on the server (NFR-05) and is tested against the Firestore emulator.

```
lib/
  models/       Plant, Nursery, Professional, Listing, AppUser, PriceRange
  data/         repository interfaces, LocalBackend, seed data
  logic/        search and Arabic text matching, phone validation, route access rules
  state/        AppState (language, cart, notices)
  ui/           screens per role
test/           unit tests and end-to-end widget tests per user story
firebase/       Firestore security rules and emulator tests
```

## Run locally

```bash
flutter pub get
flutter run -d chrome            # or an Android emulator
flutter test                     # 107 unit and widget tests
cd firebase && npm ci && npm test   # 24 security-rules tests (needs Java 11+)
```

On every push to `main`, GitHub Actions runs the tests and deploys the web build to GitHub Pages.
