# Botanical Cinema — living atlas refinement

Owner direction, September 14, 2026: keep the approved Botanical Cinema theme, make it substantially more botanical and cinematic, add useful playful interactions, simplify all public copy, update the shared skill/theme, and publish to the existing Posit app.

## What changed

- Original generated copperplate-style botanical panorama, treated as a full-screen landscape and three distinct world plates. Oversized film-title type, dark projection framing, warm paper, specimen numbering and a filmstrip carry the theme through the page.
- Slow projector light, finite opening development, world-reel seating, paper-section arrivals and a confirmed-save stamp. Motion can be paused; reduced-motion and Save-Data preferences stop the effects, and offscreen/hidden-page atmosphere pauses.
- Optional 2× artwork lens with pointer movement and native horizontal/vertical sliders. It respects the actual crop, leaves vertical scrolling and pinch zoom available, and disables itself when the illustration cannot load. This is an illustration viewer, not plant identification.
- A per-visit field notebook saves the current world, family, all selected states, counts and percentages. Twelve unique world/family comparisons fit; resaving replaces that family’s saved counts and the thirteenth removes the oldest with a notice. Cards show three rows and provide all rows in a labeled table. CSV includes source, analytical basis and capture time. Empty selection cannot save. Stale selection events cannot save or earn a stamp.
- Short, plain action labels and explanations. Detailed methods remain available; generated artwork is disclosed.
- A dedicated 1200×800 social image and initial-HTML Open Graph/Twitter metadata on the existing public origin.

The USDA bundle, curated family mappings, counts, ranking and normalization are unchanged. The GitHub Pages cover is not reskinned in this pass.

## Evidence

- 28 offline data/chart contract checks passed.
- 22 notebook UI, snapshot, export and real-server checks passed, including stale-selection rejection, replacement, 12-note bound, empty state and safe HTML.
- Existing real Shiny server transitions passed: world/family/metric, empty/invalid selection and all 50 places.
- JavaScript syntax, R/Sass rendering, whitespace checks and the 15-file deployment manifest passed. Existing R/package deployment pins are retained.
- Actual browser checks covered 1440×900, 851×900, 390×844, 320×568 and 844×390. Layout settled without horizontal overflow or Shiny output errors. The tiny phone opening retains a visible primary action.
- Browser checks covered all three worlds, lens keyboard movement, three saved families, removal, the actual CSV handler (six retained rows, Arizona Poaceae=675 and source/basis present), paused motion, dark mode, keyboard state removal, empty save disabling, reset and national percentages.
- Removing the atlas asset produced failed images while world selection and saved counts still worked. The final fallback also disables the lens. Reduced-motion/Save-Data/no-JavaScript behavior was checked in source; those device/browser modes were not simulated as executed tests.

## Assets and source

Runtime artwork: `www/cinema/atlas-v2.webp` (2172×724, about 605 KB); social card: `www/cinema/share-v2.jpg` (1200×800, about 605 KB). Built-in image generation created both; encoding was optimized locally. Exact prompts and generated-source pointers are in `artwork-v2.md`. The artwork depicts imagined botanical settings and is not an identification plate, observed vegetation, filming-location evidence or licensed franchise art.

Cache-sensitive assets use v2 filenames. The manifest includes only runtime R, data and assets; it excludes the 32 MB raw CSV and old v1 assets. Rollback to the prior source commit and its manifest restores the prior application. No dependency update is needed for this pass.

## Release target

Authorized production URL: https://019ecc91-3c6c-bee2-f824-0ea23fc60ac6.share.connect.posit.cloud/

Source repository: https://github.com/tgilbert14/PlantsInMovies — existing default branch `main`. The existing host is configured from GitHub per the project deployment notes. Publish only the tested committed source, then verify the live app, artwork, metadata and a real saved-family action. A Git push alone is not evidence of a successful Posit release. Final live verification belongs in the run ledger and release response.
