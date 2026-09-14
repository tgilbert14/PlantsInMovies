# Plants in Movies — theme decision, 2026-09-14

Status: Botanical Cinema explicitly approved and implemented locally. See handoff.md for executed checks and release boundary. No publication performed.

## Scope and baseline

Reskin the existing R/Shiny app at https://019ecc91-3c6c-bee2-f824-0ea23fc60ac6.share.connect.posit.cloud/ . The owner explicitly identified the app as the target, not the GitHub Pages cover. Source baseline: e31d871, https://github.com/tgilbert14/PlantsInMovies . Local checkout: /Users/timbo/Documents/Codex/Projects/PlantsInMovies . R 4.5.2 and the major required packages are installed.

The app uses bslib, herbarium SCSS, interactive ggiraph bars, circlize shared-species diagrams and precomputed RDS files. It has three curated worlds, state selection, two metric displays, family tooltips, PNG downloads, a light/dark control, startup loader and a first-visit welcome modal. The public cover and app were opened in the browser; the live app's default results, controls and source were inspected. Full baseline responsive QA remains to be completed during implementation.

Audience: curious movie fans and plant enthusiasts. Outcome: make exploring the relationship between curated movie worlds and state plant checklists immediately inviting, while letting visitors inspect the evidence.

Preserve: R/Shiny runtime, existing data and family assignments, state comparison, chart drilldowns, shared-species map and downloads, provenance, accessibility, contact/DDL links, educational/non-affiliation notice and current host.
Improve: cinematic identity, responsive hierarchy, clearly labeled state controls, selection feedback, chart readability, keyboard access to family details and consistent dark mode. Assess whether the blocking welcome and redundant refresh action remain useful.
Retire: generic card dominance, ornamental suite navigation within the main task, misleading normalization claims. Do not retire usable analytical functions.

## Three comparable style-guide previews

Artifact: style-options.html . Lightweight interactive samples only; same verified Arizona data in all three, with world buttons. These controls demonstrate styling and feedback; they do not approve or deploy a theme.

1. Recommended NEW `botanical-cinema` — Botanical Cinema. Ink, cream, leaf green and amber; condensed poster headings and serif details; a film-frame world selector carries into readable evidence panels. New organizing idea: cinematic selection and botanical evidence share a single app experience. It combines film character and scientific reading space without borrowing film assets. Potential signature: selecting a world reveals its family contributions and keeps state/metric selection continuous into the shared-species view.
2. EXISTING `cinematic-desert-fieldbook` — Cinematic Desert Fieldbook, adapted to a botanical film archive. Paper, forest, clay and sage; editorial serif and clear controls; botanical plate selection and stamped feedback. Closest to the current herbarium, hence less visually transformative. Avoid suggesting all movie worlds are deserts.
3. EXISTING `vhs-retro-vice-city` — VHS Retro / Vice City, adapted to a botanical video library. Midnight, lilac, mint and peach; condensed headings and mono captions; tape selection and a brief frame transition. Strong entertainment appeal with a greater risk of visual noise around science. Use original graphics; no game/film artwork, soundtrack, persistent tracking effects or autoplay sound.

Approved direction: `botanical-cinema`, explicitly selected by the owner on September 14, 2026. Owner requires three brief visual samples and explicit approval on every new revamp. Existing approved directions remain in force for refinements unless a switch is proposed.

## Data evidence and claim corrections

Read from committed data/meta.rds: bundle built 2026-06-15 11:17 MST, 50 state/territory entries, 34,400 unique symbols, 253,544 raw rows. Entries include Puerto Rico and exclude Rhode Island. Do not describe coverage as all fifty states.

Arizona: Arrakis 1,399 / 4,932 = 28.4%; Middle-earth 1,679 / 8,552 = 19.6%; Isla Nublar 205 / 1,236 = 16.6%. Values verified against RDS and rendered live app. Preview labels use plant records because the source counts unique USDA symbols; species-level interpretation should be checked against taxonomy before stronger claims.

R/charts.R computes fair = round(100*n/pool_us,1). A constant denominator per world preserves that world's state ranking and does not adjust for area/richness or family sizes. Correct the descriptive copy in the reskin; retain the formula unless separately deciding a methodological change. No inference of ecological suitability or actual movie filming location is warranted.

## Feature pass planned before approval (execution in handoff.md)

| Family | Intended treatment / fit | Evidence or pending work |
| --- | --- | --- |
| Original continuity | Existing app reskin, same official target; local previews clearly labeled | Live app and source links verified in UI/source |
| Commercial / trust / media | USDA provenance, family curation, DDL identity and non-affiliation; no commercial offers, ratings or official film embeds in app UI/source inspected | Preserve actual links; no invented endorsements/media |
| Arrival | A concise, nonblocking cinematic or field-guide arrival fitting selected style | Final choice pending |
| Operable signature | World selection connected to family contributions and state comparison | Preview world selection implemented; full app integration pending |
| State continuity | States, world, metric and chart/download output agree | Current reactive graph inspected; implementation QA pending |
| Rewarding actions | Immediate pressed and selected feedback; stronger flourish only for meaningful exploration | Preview supports native buttons, visible focus and reduced motion |
| Inputs / lifecycle | Keyboard, touch, interruption, empty states, missing media, reduced motion | Full app checks pending |
| Shared first impression | Review metadata if public reskin is authorized for release | Current task has not authorized deployment |
| Release versions | Update asset references and deployment manifest from clean source before an authorized release | Existing Posit host retained; no production changes |

## Acceptance after approval

Run the actual app locally. Test 1440x900, 851x900, 390x844, 320x568 and landscape; keyboard/focus, dark/reduced motion, empty/many states, chart details, real PNG exports and startup/failure behavior. Shiny requires JavaScript for analysis; provide a readable explanation and usable links when unavailable. Keep animations transform/opacity based; avoid new media/dependency overhead for reskin. Target no chart latency regression, immediate selection acknowledgment, zero unexpected overflow and readable controls at all required sizes. Record measured performance and screenshot evidence after implementation.

Deployment is not authorized by choosing a theme. Prepare a clean source change and refreshed manifest, then follow existing release authority. Preserve the public cover unless the owner expands scope.

## Decision-preview verification

Executed browser checks of style-options.html: actual 1280x720 desktop rendering; 390x844 phone rendering and lower-card inspection; 320x568 overflow measurement. No horizontal overflow in these checks. Clicked the first style's Middle-earth button and verified its selected state, 1,679 records and 19.6% national-pool share. Temporary viewport override reset. These checks cover the decision preview, not a completed app reskin. Comparison is served locally at http://127.0.0.1:8768/style-options.html . Shared revamp skill validation passed after the owner-requested approval and three-preview edits.

## Approved implementation — September 14

The owner explicitly approved Botanical Cinema and requested the revamp. Theme ID `botanical-cinema` remains selected. App-only implementation is authorized; publication remains a separate decision under the stated boundary.

Thesis: operate a botanical screening table. A filmstrip of three illustrated worlds opens a world-specific state comparison; a specimen sheet reveals every contributing family and its share in each selected state. This turns the existing tooltip evidence into a readable, keyboard-accessible discovery. Original SVG botanical illustrations carry the cinematic opening and selection; actual records carry the analysis. No franchise artwork or fictional scientific claims.

Arrival: immediate title and controls, one 550ms scene seating animation, no welcome modal. Main: world selection changes scene and state comparisons. Discovery: family selection reveals its contribution across selected states. Exports carry current selection and a factual title. Scene animation is finite; motion toggle and reduced-motion/Save-Data paths stop it. No optional sound or blocking intro.

Budgets: original SVG art plus custom CSS/JS below 100KB uncompressed; no added frontend libraries or remote media; control feedback within 100ms; normal scene settle <=550ms; no new continuous animation; no JS-dependent hidden initial content. Keep Shiny's existing reactive packages and precomputed data. Verify rendered startup and interactions locally, record limitations on production latency, CWV and cross-browser tests.
