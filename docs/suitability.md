# Suitability scoring (Sprint 2: US-07 to US-12)

Code: `lib/logic/suitability.dart` (rules), `lib/logic/citation.dart` (sources), `lib/ui/customer/choose_screen.dart` (screens). Tests: `test/logic/suitability_test.dart`, `test/flows/choose_flow_test.dart`.

## Questions (US-07)

One per screen with a progress bar. The window question is asked only for "inside the house"; the sun question only for a balcony, roof, yard or garden. "Skip" on any question opens Buy Plants with no filter (US-08).

| # | Question | Answers |
|---|---|---|
| 1 | Which city? | the five app cities |
| 2 | Where will the plant be? | inside / balcony or roof / yard or garden |
| 3a | Near a window? (inside) | sunny window / bright, no direct sun / far from a window |
| 3b | Sun hours? (outside) | most of the day / a few hours / little or none |
| 4 | Room? | small pot / big pot on the floor / ground |
| 5 | How often can you water? | every two weeks or less / weekly / every 2–3 days |
| 6 | Children or pets? | yes / no |

## Score (US-09)

Each plant gets four factor scores from 0 to 100, compared with its knowledge-base values:

| Factor | Weight | Rule (answer vs plant) |
|---|---|---|
| Place | 25 | 100 if the plant's placements include indoor/outdoor as answered, else 0 |
| Light / sun | 30 | equal 100; one step more light 70, two more 30; one step less 40, two less 0 |
| Water | 25 | equal 100; waters one step more 70, two more 40; one step less 30, two less 0 |
| Space | 20 | fits exactly 100; more room 85; one size too big 20; two too big 0 |

Total = weighted average, rounded. A plant is shown only if the total is at least 60 and no factor is 0. Toxic plants (ASPCA, OD-10) are never shown when children or pets = yes. Top 10, highest first; ties put guide-backed plants first, then by name, so results are repeatable.

Plant size comes from its type: trees and palms large; shrubs and climbers medium; the rest small.

## Sources and not covered (US-10, US-11)

Guide-backed plants show the guide, edition and section, and "Why this score?" lists the plant values used next to the customer's answers. Plants outside the guide are labelled instead. Section is by plant type until TF-06 records each entry's exact section in `Plant.guideSection`.

Cities other than Riyadh get "not covered yet" (OD-04). If no plant passes, the app names the answer that ruled out the most plants and links back to that question.

## Nursery comparison (US-12)

Tapping a result lists verified nurseries with the plant in stock, cheapest first, with rating and city, or "not available in nurseries yet".

## Plant data editing (US-14)

Admin tab "Plant data": edit place, sun, water, watering interval and toxicity. Results use the change immediately. Each changed field is logged with editor, time, old and new value (`plantEdits`, append-only in `firestore.rules`).
