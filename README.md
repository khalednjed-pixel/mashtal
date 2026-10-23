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
- **Backend:** Sprint 1 runs on `LocalBackend`, which keeps data on the device, because the team's Firebase project is not set up yet. The screens use the `AuthRepository` and `MarketRepository` interfaces, so Firebase can replace it without changing them. See [docs/data-model.md](docs/data-model.md).
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
flutter test                     # 52 unit and widget tests
cd firebase && npm ci && npm test   # 16 security-rules tests (needs Java 11+)
```

On every push to `main`, GitHub Actions runs the tests and deploys the web build to GitHub Pages.
