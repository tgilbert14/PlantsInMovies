> Superseded by the owner-authorized all-out refinement in [handoff-v2.md](handoff-v2.md). The earlier local-only publication boundary below records the previous pass.

# Plants in Movies — Botanical Cinema

The owner approved theme `botanical-cinema` after reviewing three style samples. This run reskins the R/Shiny app, not the GitHub Pages landing page.

Local app: http://127.0.0.1:7474/ . Source branch: `codex/botanical-cinema` in this repository. Production at https://019ecc91-3c6c-bee2-f824-0ea23fc60ac6.share.connect.posit.cloud/ has not been changed. No push or deployment was performed.

## What changed

A filmstrip of three original botanical plates leads into a world-specific state comparison. The same selections flow into a full family contribution view, three-world chart, exact data tables and exports. The style uses a dark film-poster masthead, cream evidence panels, condensed titles, serif details and restrained world colors. The drawings are explicitly illustrative and use no franchise assets.

State changes update immediately; the welcome overlay and redundant refresh button were removed. Controls have pressed, selected and keyboard focus states. Finite 550ms scene seating can be paused; device reduced-motion/Save-Data preferences disable it. The app has no autoplay audio or continuous animation. Dark mode preserves readable data surfaces.

The family close-up exposes every curated family through native keyboard/touch controls instead of limiting evidence to chart tooltips. Results include real counts and percentages, including explicit zero records. Long result lists and data tables are named keyboard-scrollable regions. State-removal buttons have individual names, Space/Enter activation and focus return; deferred Selectize focus is handled so it cannot reopen the dropdown over reset.

The original record-count and national-pool calculations, mappings and all data files remain unchanged. The former “Fair share” copy is now “National pool %”: a fixed world denominator does not correct for state size or large families. Counts are labeled plant records/USDA symbols because taxa below species level occur in the source. Coverage explicitly includes Puerto Rico and excludes Rhode Island.

The PNG connection map has a title, readable labels and provenance. Phone maps omit crowded tick labels but retain sector names, a key and exact data-table access. Maps use up to eight places; larger selections retain exact connections in the table and CSV rather than emit an unreadable image. CSV columns distinguish curated world-to-state links from full-checklist state-to-state links and include source/bundle metadata. Both filenames identify the selected places.

## Verification executed

- `Rscript scripts/check-data-contract.R`: 28 offline checks passed (worker run, independently repeated by review). Covers data totals, family sums, Arizona anchors, USDA-symbol interpretation, coverage, zero-filled missing states, wide/narrow/zero chart generation and serialization.
- `Rscript tests/check-shiny-state.R`: passed on final source. Exercises real server transitions across world/family/metric selection, empty and invalid selection, and all 50 available places.
- `node --check www/cinema-v1.js`, `git diff --check`: passed.
- `python scripts/refresh-manifest-files.py --check`: all 15 runtime paths/checksums correct. New custom art/CSS/JS occupy approximately 60KB on disk, below the 100KB custom-asset budget. No new frontend dependency or remote media/font request added.
- Browser: measured 1440×900, 851×900, 390×844, 320×568 and 844×390. Inspected opening, comparison, family section, chart, connection map and footer across desktop/phone passes. Settled layouts had no horizontal overflow or Shiny output errors. A widget can briefly retain its old width during responsive recalculation; the settled narrow chart was inspected separately.
- Browser actions: world switching, keyboard family activation with focus retained, both metrics, empty selection, reset, zero-count family, state removal with Space and focus return, dark mode, motion pause/resume, and phone vertical chart facets.
- Missing art: temporarily removed the Arrakis SVG; confirmed both images failed to load while heading, selections and exact comparison values stayed usable with no Shiny output error. Restored the file and verified manifest checksum.
- PNG: clicked the real download and retrieved its current local session endpoint; `connection-map-browser.png` is 1800×1800 and was visually inspected. CSV: retrieved the actual handler into `connections-browser.csv`; verified 12 default-selection rows and both connection types/bases. The older `connection-map-check.png` is a direct-render QA artifact.
- Read-only specialist review found no unresolved P0/P1 issues; its accessibility and export-context findings were addressed.

Limits: this is local embedded-browser QA, not physical-device or independent Safari/Firefox certification. The explicit motion-off path was exercised; OS-level reduced-motion/Save-Data emulation was not available through the selected browser surface. The no-JavaScript explanation and source link were source-checked, not executed with browser JavaScript disabled. Scientific charts remain interactive Shiny outputs and require JavaScript. No production cold-start/Core Web Vitals, live metadata crawl, messaging unfurl or deployment verification is claimed.

## Feature pass outcome

| Family | Implemented result / evidence |
| --- | --- |
| Original continuity | Existing app/runtime/host retained; public landing untouched; current app URL recorded above |
| Trust and media | Existing USDA source, curated mappings, contact and non-affiliation preserved; no app reviews/offers/owned film embeds to reproduce |
| Arrival | Immediately readable cinematic heading and filmstrip; short finite scene arrival; no blocking modal |
| Operable signature | World plate → state comparison → complete family contribution view; real source counts |
| State continuity | Same selected states/metric in world summary, all-world chart, tables and export graph; world selection scopes family evidence |
| Rewarding actions | Immediate pressed/selected states; native keyboard controls and finite seating motion |
| Input/failure | Responsive/input checks above; empty state, map cap, missing art, focusable overflow regions |
| Shared first impression | App document title/description updated; public share-card work deferred because no new public release/share link was requested |
| Release assets | New v1 asset names; bslib compiles CSS; complete manifest file inventory prepared; no release performed |

## Release preparation and boundaries

Run locally with `Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=7474)'`.

`rsconnect` is not installed in this Mac's active R library. The existing deployment package pins are preserved; `scripts/refresh-manifest-files.py` updates source/asset inventory and MD5 checksums only. `scripts/write_manifest.R` also has the correct runtime file list for regeneration in the established deployment environment. The 32MB source CSV stays excluded. No tooling was installed.

Local R is 4.5.2. Some installed package versions differ from the existing deployment pins (local shiny 1.14.0/bslib 0.12.0/circlize 0.4.18 versus pinned 1.13.0/0.10.0/0.4.17). Code uses existing established APIs, but the Posit build and live app must be checked when publication is authorized. Do not claim deployed-environment parity from local success.

The next owner decision is publication of the reviewed reskin to the established Posit app. Theme approval does not itself authorize that production change. Before an authorized deployment, use a clean source commit, verify the target branch/manifest and preserve the previous release. Rollback is the unchanged baseline commit `e31d871` and its existing manifest/assets. Do not repoint the public landing or change domain behavior as part of this reskin.

## Learning

The largest improvement is the continuity between cinematic identity and real evidence: the first world choice carries into readable comparisons and family discovery. Quiet paper keeps the dramatic opening useful for analysis. Source-level checks caught misleading normalization language and USDA symbol/species ambiguity; rendered QA caught Shiny display-contents behavior, crowded chart ticks and Selectize's deferred focus. The portable lesson is to make the source evidence the meaningful second layer of an expressive data app.
