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

## Sprint 3: Reserve and My Garden (US-15 to US-24)

| Story | What works |
|---|---|
| TF-03 Firebase | Accounts and all shop data are in Firebase (project `mashtal-1`, free Spark plan), shared by every device. |
| US-15 Cart | The cart is a pickup route: one numbered stop per nursery with its plants and subtotal, and a note that each nursery is a separate pickup. A plant that sold out or was hidden stays in the cart, marked, and is not reserved. |
| US-16 Reserve | Reserving sends one request per nursery and empties the cart. |
| US-17 Accept or reject | The nursery accepts (the 48-hour hold starts) or rejects with a reason the customer sees. |
| US-18 Directions | An accepted reservation shows a pickup pass: address, opening hours, how much of the hold is left, a Directions button that opens the map app at the nursery, and a call button. The admin sets each nursery's map point (or pastes a Google Maps link). |
| US-19 Notices | The customer is told in the app when a reservation is accepted, rejected, has 6 hours left, or has expired: a banner, a count on Account and a Notifications list. Push needs Cloud Functions (paid plan), so the app works the notices out itself from `acceptedAt` + 48 hours and checks every 30 seconds. |
| US-20 Pickup | The nursery marks an accepted reservation picked up and the plants appear in the customer's My Garden. Pending, rejected or expired reservations cannot be marked. |
| US-21 My Garden | One card per plant with photo, name, watering frequency ("every 3 days") and the next seven days as watering drops. Plants due today are listed first; a drop records a watering. The empty garden offers Buy Plants and Add a plant manually. |
| US-22 History | Each garden plant has a page with its history, newest first, with date and source: how it arrived, waterings and the customer's notes. Ask Mashtal results and professional feedback join it in Sprint 4 (AC-02, the professional's view, moved to Sprint 4). |
| US-23 Book Plant Care | A button on every garden plant asks what it needs (pruning, periodic care, treatment) and opens the professionals list filtered by it. |
| US-24 Professionals | Verified professionals covering the customer's city and the chosen service, best rated first, with jobs done and the price range the admin set. "No professionals in your area yet" when nobody covers the city. |

### Guide citations

Every plant the app calls guide-backed now cites its exact portrait in the *Manual of Riyadh Plants* (English version, 1st edition 2014), for example "Part 2: Plant portraits, p. 230" for the date palm, with the manual's name when it differs from ours (*Cassia italica* for *Senna italica*). 30 of the 33 outdoor plants have a portrait. Ghaf (*Prosopis cineraria*) is only mentioned on the *Prosopis chilensis* page, and wild moringa (*Moringa peregrina*) and markh (*Leptadenia pyrotechnica*) are not in the manual, so these three are now labelled "not from the official guide" instead of being cited.

## Beyond the sprints: care plan and extras

| Feature | What works |
|---|---|
| Care plan | Each garden plant's watering adapts to the Riyadh season (summer more often, winter less), where it lives (in the ground, a big pot, a small pot, indoors), and whether it is new (more water while it settles in). The plant page says why, e.g. "Every 3 days now · new plant · big pot". |
| Check the soil | Reminders ask the customer to check the soil. "Soil is still moist" moves the next check a little later and slowly stretches that plant's pace, so the plan learns the home. "How do I tell?" explains the finger test. |
| Hold to water | The plant page's main action is a round "soil" that drains as days pass and turns sandy when dry. Press and hold fills it with water (a quick tap does nothing), with a small vibration on phones. Garden cards show the same moisture ring. |
| Where it lives | Asked once when a plant is added by hand, with the app's guess marked. Picked-up plants start with the guess and can be changed in one tap. |
| Choose question | For a few hours of outdoor sun: morning or afternoon? Riyadh's afternoon sun counts as full sun; "not sure" changes nothing. |
| Going away | In My Garden: how long, and will someone at home (a maid or family) water? If yes, a simple watering plan per plant to send on WhatsApp, in Arabic or English. If not, what to do before leaving and which plants will not last that long alone, with when they need water. Away mode shows on My Garden; on return it says to check every plant's soil. Kept on the device. |
| Look | Plant photos are framed in a Najdi arch. Answers in Choose, where a plant lives, going away, the Today panel and the empty screens use one set of simple garden line drawings drawn in code (`lib/ui/widgets/garden_art.dart`). |
| Saved, share, tips | A heart saves plants to a Saved list; the plant page shares a plant on WhatsApp or as a link; garden plants show general care tips. |

These are general household rules, not quotes from the guide, and the screens say "check the soil" rather than promising exact days. Watering colours (`water`, `waterLight`, `waterSoft`) are the one colour family outside the greens and are used for water only.

## Try it

Open the live demo and use a demo account. **There is no real SMS**: the code is shown on screen.

| Number | Role |
|---|---|
| 0500000001 | Admin |
| 0500000002 | Nursery (verified: Al Rawdah) |
| 0500000003 | Nursery (pending: Al Fajr) |
| 0500000004 | Professional |
| 0500000005 | Customer |

Any other 05 number registers as a new customer.

The web demo now keeps its data in Firebase (project `mashtal-1`), so every phone sees the same nurseries, listings and accounts. The first time the admin number signs in, the app uploads the demo data. *Account → Reset demo data* only exists in the offline build (`--dart-define=MASHTAL_OFFLINE=true`).

## How it is built

- **Flutter** (Android and web from one codebase), with `provider` for state, `go_router` for navigation and the route guards, and the Tajawal font.
- **Backend (TF-03):** Firebase project `mashtal-1` on the free Spark plan. Accounts use Firebase Authentication and all data (accounts, nurseries, professionals, listings, plants, price ranges, photos) is in Cloud Firestore. `LocalBackend` keeps its permission checks and in-memory lists; `FirebaseServices` (`lib/data/firebase_services.dart`) fills them from Firestore and saves every change there. Without Firebase settings for a platform (for now: Android), the app runs on the offline demo data. See [docs/data-model.md](docs/data-model.md).
- **Sign-in:** the screens are unchanged: phone number, then the code shown on screen. After a correct code the app signs in to a hidden Email/Password account named after the number. This avoids paid SMS but does not truly verify the phone, which is acceptable for the course demo.
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
flutter test                     # unit and widget tests
cd firebase && npm ci && npm test   # security-rules tests (needs Java 11+)
```

Against the local Firebase emulators instead of the real project:

```bash
cd firebase && npx firebase emulators:start --only auth,firestore --project demo-mashtal
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

### Firebase project setup (done once)

1. Authentication → Sign-in method → enable **Email/Password**.
2. Firestore → create the database, then publish `firebase/firestore.rules` (Rules tab, or `npx firebase deploy --only firestore:rules` from `firebase/`).
3. Firestore → Data → add collection `partnerAccounts`, document id `+966500000001`, field `role` = `admin`. This makes 0500000001 the admin; every other partner account is created by the app.
4. Sign in to the app as 0500000001 once to upload the demo data.

On every push to `main`, GitHub Actions runs the tests and deploys the web build to GitHub Pages.
