#!/usr/bin/env Rscript

# Offline integrity checks for the precomputed Plants in Movies data bundle and
# the ggiraph chart contract. Run from any directory with:
#
#   Rscript scripts/check-data-contract.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[startsWith(args, "--file=")]
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)
} else {
  normalizePath("scripts/check-data-contract.R", mustWork = TRUE)
}
project_dir <- dirname(dirname(script_path))
old_dir <- setwd(project_dir)
on.exit(setwd(old_dir), add = TRUE)

suppressPackageStartupMessages(library(dplyr))
source("R/biomes.R")
source("R/charts.R")

checks_run <- 0L
check <- function(condition, label) {
  if (length(condition) != 1L || is.na(condition) || !condition) {
    stop("FAIL: ", label, call. = FALSE)
  }
  checks_run <<- checks_run + 1L
  message(sprintf("ok %02d - %s", checks_run, label))
  invisible(TRUE)
}

message("Plants in Movies data contract (offline)")

data_files <- c(
  biome_tally = "data/biome_tally.rds",
  biome_totals = "data/biome_totals.rds",
  biome_pool = "data/biome_pool.rds",
  state_biome_family = "data/state_biome_family.rds",
  state_richness = "data/state_richness.rds",
  meta = "data/meta.rds"
)
check(all(file.exists(data_files)), "all required precomputed artifacts exist")

bundle <- lapply(data_files, readRDS)
invisible(list2env(bundle, envir = environment()))

schemas <- list(
  biome_tally = c("State", "Movie", "n"),
  biome_totals = c("Movie", "pool_us"),
  biome_pool = c("Movie", "Family", "n_us"),
  state_biome_family = c("State", "Movie", "Family", "n"),
  state_richness = c("State", "total_species")
)
for (object_name in names(schemas)) {
  check(
    identical(names(bundle[[object_name]]), schemas[[object_name]]),
    paste(object_name, "keeps its column contract")
  )
}

check(
  all(biome_tally$n >= 0) && all(state_biome_family$n >= 0) &&
    all(biome_pool$n_us >= 0) && all(biome_totals$pool_us > 0),
  "precomputed counts and national denominators are valid"
)

# Every state/world total must be the sum of its family rows.
family_totals <- state_biome_family %>%
  group_by(State, Movie) %>%
  summarise(n_from_families = sum(n), .groups = "drop")
state_total_check <- full_join(
  biome_tally,
  family_totals,
  by = c("State", "Movie")
)
check(
  nrow(state_total_check) == nrow(biome_tally) &&
    all(!is.na(state_total_check$n)) &&
    all(!is.na(state_total_check$n_from_families)) &&
    all(state_total_check$n == state_total_check$n_from_families),
  "every state/world total equals the sum of its family counts"
)

# Because each USDA symbol maps to one family, national family pools must sum
# to the unique-symbol denominator for their world.
pool_totals <- biome_pool %>%
  group_by(Movie) %>%
  summarise(pool_from_families = sum(n_us), .groups = "drop")
national_total_check <- full_join(biome_totals, pool_totals, by = "Movie")
check(
  nrow(national_total_check) == length(.biome_order) &&
    all(national_total_check$pool_us == national_total_check$pool_from_families),
  "every national pool equals the sum of its family pools"
)

# Coverage is intentionally the repository's 50 checklist areas: Puerto Rico
# is present and Rhode Island is absent in this USDA export.
states <- sort(unique(meta$states))
check(
  length(states) == meta$n_states && meta$n_states == 50L &&
    identical(states, sort(meta$states)),
  "metadata declares 50 unique checklist areas"
)
check(
  setequal(states, state_richness$State) && setequal(states, biome_tally$State),
  "state coverage agrees across metadata, richness, and biome totals"
)
expected_cells <- expand.grid(
  State = states,
  Movie = .biome_order,
  stringsAsFactors = FALSE
)
check(
  setequal(
    paste(biome_tally$State, biome_tally$Movie, sep = "\r"),
    paste(expected_cells$State, expected_cells$Movie, sep = "\r")
  ),
  "every covered state has one row for each movie world"
)
check(
  "Puerto Rico" %in% states && !"Rhode Island" %in% states,
  "coverage includes Puerto Rico and records Rhode Island as missing"
)

# The public Arizona example is an anchored regression check for counts,
# denominators, ratios, table columns, and film labels.
arizona <- build_match_table(
  "Arizona", biome_tally, biome_totals, state_biome_family, state_richness
)
table_columns <- c(
  "State", "Movie", "n", "pool_us", "fair", "top", "film", "Movie_lab"
)
check(identical(names(arizona), table_columns), "build_match_table keeps its column contract")

az_expected <- data.frame(
  Movie = .biome_order,
  n = c(1399L, 1679L, 205L),
  pool_us = c(4932L, 8552L, 1236L),
  fair = c(28.4, 19.6, 16.6),
  film = c("Dune", "Lord of the Rings", "Jurassic Park"),
  stringsAsFactors = FALSE
)
az_rows <- arizona[match(az_expected$Movie, arizona$Movie), ]
check(
  identical(as.integer(az_rows$n), az_expected$n) &&
    identical(as.integer(az_rows$pool_us), az_expected$pool_us),
  "Arizona counts and national denominators match the published example"
)
check(
  isTRUE(all.equal(as.numeric(az_rows$fair), az_expected$fair, tolerance = 1e-12)) &&
    isTRUE(all.equal(
      as.numeric(az_rows$fair),
      round(100 * az_expected$n / az_expected$pool_us, 1),
      tolerance = 1e-12
    )),
  "Arizona national-pool ratios use 100 x state symbols / national symbols"
)
check(
  identical(as.character(az_rows$film), az_expected$film),
  "world-to-film lookup is named and maps every Arizona row correctly"
)

# A state missing from the bundle still receives three truthful zero rows.
with_missing_state <- build_match_table(
  c("Arizona", "Rhode Island"),
  biome_tally, biome_totals, state_biome_family, state_richness
)
missing_rows <- with_missing_state[
  as.character(with_missing_state$State) == "Rhode Island",
]
check(
  nrow(missing_rows) == length(.biome_order) &&
    all(missing_rows$n == 0L) && all(missing_rows$fair == 0) &&
    all(missing_rows$top == "&mdash;"),
  "a missing state is zero-filled across all worlds"
)

# A completely empty source and zero national pool must remain finite so the
# all-zero chart can render a useful state rather than fail on NaN scales.
zero_totals <- biome_totals
zero_totals$pool_us <- 0L
all_zero <- build_match_table(
  "No data state",
  biome_tally[0, ], zero_totals, state_biome_family[0, ], state_richness[0, ]
)
check(
  nrow(all_zero) == length(.biome_order) && all(all_zero$n == 0L) &&
    all(all_zero$fair == 0) && all(is.finite(all_zero$fair)),
  "all-zero counts and denominators produce finite zero ratios"
)

# Rebuild the symbol-level aggregations from the checked-in USDA export when it
# is available. This proves that `n` means distinct USDA symbols; it does not
# make an unverified species-level taxonomic claim.
raw_path <- "www/my_plant_data.csv"
if (file.exists(raw_path)) {
  check(requireNamespace("readr", quietly = TRUE), "readr is available for symbol provenance checks")
  raw <- suppressMessages(readr::read_csv(
    raw_path,
    show_col_types = FALSE,
    col_select = c("symbol", "State", "Family")
  ))
  check(
    nrow(raw) == meta$n_raw_rows && dplyr::n_distinct(raw$symbol) == meta$n_species,
    "raw row and unique-symbol counts agree with metadata"
  )
  slim <- distinct(raw, State, symbol, Family)
  symbol_families <- slim %>% distinct(symbol, Family) %>% count(symbol)
  check(
    nrow(slim) == nrow(raw) && all(symbol_families$n == 1L),
    "each checked-in USDA symbol maps to one family"
  )

  mapped <- slim %>%
    mutate(Movie = assign_biome(Family)) %>%
    filter(!is.na(Movie))
  rebuilt_tally <- mapped %>%
    distinct(State, Movie, symbol) %>%
    count(State, Movie, name = "n_from_symbols")
  symbol_tally_check <- full_join(
    biome_tally,
    rebuilt_tally,
    by = c("State", "Movie")
  )
  check(
    nrow(symbol_tally_check) == nrow(biome_tally) &&
      all(symbol_tally_check$n == symbol_tally_check$n_from_symbols),
    "all state/world counts equal distinct USDA-symbol counts"
  )
} else {
  message("skip - checked-in USDA CSV is unavailable; symbol rebuild not run")
}

# Exercise the real ggiraph render path at desktop and phone geometry, retain
# the PNG toolbar, and verify the all-zero rendering path.
sample_table <- build_match_table(
  c("Arizona", "California", "Maine"),
  biome_tally, biome_totals, state_biome_family, state_richness
)
wide_chart <- build_match_girafe(
  sample_table, mode = "raw", width_svg = 8.5, stacked = FALSE
)
narrow_chart <- build_match_girafe(
  sample_table, mode = "fair", width_svg = 4.2, stacked = TRUE
)
zero_chart <- build_match_girafe(
  all_zero, mode = "fair", width_svg = 4.2, stacked = TRUE
)
check(
  inherits(wide_chart, "girafe") && inherits(narrow_chart, "girafe") &&
    inherits(zero_chart, "girafe"),
  "wide, narrow-stacked, and all-zero ggiraph charts generate"
)
check(
  narrow_chart$x$ratio < wide_chart$x$ratio && zero_chart$x$ratio < 1,
  "narrow stacked charts use readable vertical geometry"
)
check(
  identical(wide_chart$x$settings$toolbar$pngname, "flora-match-raw") &&
    identical(narrow_chart$x$settings$toolbar$pngname, "flora-match-national-pool") &&
    length(wide_chart$x$settings$toolbar$hidden) == 0L &&
    length(narrow_chart$x$settings$toolbar$hidden) == 0L,
  "PNG toolbar remains enabled for both metrics"
)
check(
  grepl("unique plant records", wide_chart$x$html, fixed = TRUE) &&
    grepl("National pool", narrow_chart$x$html, fixed = TRUE) &&
    grepl("does not adjust for state size or family-size bias", narrow_chart$x$html, fixed = TRUE),
  "rendered chart copy describes USDA symbols and the normalization limit"
)

rendered <- lapply(
  list(wide_chart, narrow_chart, zero_chart),
  htmltools::renderTags
)
check(
  all(vapply(rendered, function(x) nchar(x$html) > 1000L, logical(1))),
  "all chart widgets serialize to inline SVG markup"
)

message(sprintf("PASS: %d offline data and chart checks.", checks_run))
message("Usage: Rscript scripts/check-data-contract.R")
