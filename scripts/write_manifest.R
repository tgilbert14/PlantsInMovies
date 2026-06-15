# scripts/write_manifest.R
# ------------------------------------------------------------------------------
# Regenerate manifest.json for deployment to Posit Connect Cloud. Run after any
# change to the app, its R/ helpers, the data bundle, or package versions:
#
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" scripts/write_manifest.R
#
# Only the files the running app actually needs are bundled -- the 32 MB source
# CSV (www/my_plant_data.csv) and the dev-time scripts/ are deliberately left
# out so the deployed bundle stays tiny.
# ------------------------------------------------------------------------------

suppressMessages(library(rsconnect))

app_files <- c(
  "app.R",
  "R/biomes.R", "R/charts.R",
  "www/herbarium.scss",                      # theme stylesheet, read at runtime
  "data/biome_tally.rds", "data/biome_totals.rds",
  "data/state_biome_family.rds", "data/state_richness.rds",
  "data/state_pairs.rds", "data/meta.rds"
)

missing <- app_files[!file.exists(app_files)]
if (length(missing)) {
  stop("Missing runtime files (run scripts/precompute.R first?): ",
       paste(missing, collapse = ", "))
}

writeManifest(appDir = ".", appFiles = app_files, appPrimaryDoc = "app.R")
message("Wrote manifest.json (", length(app_files), " files bundled; source CSV excluded).")
