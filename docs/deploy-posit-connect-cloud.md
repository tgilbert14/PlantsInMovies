# Deploying Plants in Movies to Posit Connect Cloud

shinyapps.io is being retired (end of 2026). This app now targets **Posit Connect
Cloud** (https://connect.posit.cloud), which deploys Shiny apps straight from a
GitHub repository using a `manifest.json`.

## What the app needs at runtime
- `app.R`
- `R/biomes.R`, `R/charts.R`
- `data/*.rds` (6 files — the precomputed bundle, ~11 KB)

It does **not** read `www/my_plant_data.csv` (32 MB) at runtime — that file is only
the source for `scripts/precompute.R`. `manifest.json` deliberately excludes it, so
the deployed bundle is tiny.

## One-time / after-changes: regenerate the manifest
Run whenever `app.R`, the `R/` helpers, the data bundle, or package versions change:

```sh
"C:/Program Files/R/R-4.5.2/bin/Rscript.exe" scripts/write_manifest.R
```

This rewrites `manifest.json` (R 4.5.2 + the ~75 package deps incl. ggiraph & circlize).
Commit the updated `manifest.json`.

## Deploy steps
1. Push this repo (with `manifest.json` at the root) to GitHub.
2. Sign in to https://connect.posit.cloud with your Posit account.
3. **Publish → Shiny** → pick this GitHub repo + branch, app location = repo root.
4. Connect Cloud reads `manifest.json`, installs the pinned packages, and starts the app.
5. First build takes a few minutes (package install); later redeploys are faster.

## After a data refresh
1. Replace `www/my_plant_data.csv` with the new USDA export (same columns).
2. `Rscript scripts/precompute.R`  → rebuilds `data/*.rds`.
3. `Rscript scripts/write_manifest.R`  → refreshes file checksums in `manifest.json`.
4. Commit + push → Connect Cloud redeploys.

## Notes
- The old `rsconnect/shinyapps.io/...` config is legacy and unused by Connect Cloud.
- If you ever want zero cold-start static hosting, the tiny data bundle makes a
  Shinylive/webR export feasible — but verify `circlize` works under wasm first
  (the ggiraph chart will; the chord may need to be dropped).
