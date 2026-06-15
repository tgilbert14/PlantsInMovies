# scripts/precompute.R
# ------------------------------------------------------------------------------
# Turns the 32MB raw USDA export (www/my_plant_data.csv, ~253k rows) into a set
# of tiny .rds artifacts the app loads at startup. Run this ONCE whenever the
# source CSV is refreshed; the app itself never reads the CSV.
#
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" scripts/precompute.R
#
# Outputs (all in data/):
#   biome_tally.rds        State x Movie  -> # unique species (the chord biome edges)
#   state_biome_family.rds State x Movie x Family -> # species (honesty breakdown)
#   state_pairs.rds        StateA x StateB -> # shared species (the chord state edges)
#   biome_pool.rds         Movie x Family -> # species nationwide (for normalization)
#   state_richness.rds     State -> total species in mapped families
#   meta.rds               picker state list, source provenance, build timestamp
# ------------------------------------------------------------------------------

suppressMessages({
  library(tidyverse)
  library(Matrix)
})

source("R/biomes.R")

csv_path <- "www/my_plant_data.csv"
out_dir  <- "data"
dir.create(out_dir, showWarnings = FALSE)

message("Reading ", csv_path, " ...")
raw <- read_csv(csv_path, show_col_types = FALSE,
                col_select = c("symbol", "State", "Family"))

# The runtime only ever needs (State, symbol, Family). The raw file is already
# unique on this triple and symbol->Family is 1:1, but distinct() makes the
# pipeline robust to future, messier refreshes.
slim <- raw %>% distinct(State, symbol, Family)
message("Slim rows: ", nrow(slim))

# --- biome assignment ---------------------------------------------------------
mapped <- slim %>%
  mutate(Movie = assign_biome(Family)) %>%
  filter(!is.na(Movie))   # drop families not in any movie biome
message("Mapped (in-biome) rows: ", nrow(mapped))

# --- biome edges: species per state per biome --------------------------------
biome_tally <- mapped %>%
  distinct(State, Movie, symbol) %>%
  count(State, Movie, name = "n") %>%
  arrange(State, Movie)

# --- honesty breakdown: species per state per biome per family ---------------
state_biome_family <- mapped %>%
  distinct(State, Movie, Family, symbol) %>%
  count(State, Movie, Family, name = "n") %>%
  arrange(State, Movie, desc(n))

# --- national pool: how many species each family / biome contributes US-wide --
# Used for the optional normalized metric (share of a biome's national flora a
# state holds) and for honest "this family is huge" disclosure.
biome_pool <- mapped %>%
  distinct(Movie, Family, symbol) %>%
  count(Movie, Family, name = "n_us") %>%
  arrange(Movie, desc(n_us))

# National species pool per biome (the "fair share" denominator): how many
# distinct species nationwide fall in each biome's families. A state's fair-share
# score = its in-biome species / this pool, which removes the family-size bias.
biome_totals <- mapped %>%
  distinct(Movie, symbol) %>%
  count(Movie, name = "pool_us") %>%
  arrange(Movie)

# --- state richness: total in-biome species per state ------------------------
state_richness <- mapped %>%
  distinct(State, symbol) %>%
  count(State, name = "total_species") %>%
  arrange(desc(total_species))

# --- state<->state shared species (ALL pairs, precomputed) -------------------
# Sparse state x symbol incidence matrix; tcrossprod gives the full shared-
# species matrix in one cheap operation (no O(K^2) per-click loop at runtime).
sb <- slim %>% distinct(State, symbol)
st_f  <- factor(sb$State)
sym_f <- factor(sb$symbol)
M <- sparseMatrix(i = as.integer(st_f), j = as.integer(sym_f), x = 1,
                  dimnames = list(levels(st_f), levels(sym_f)))
shared <- tcrossprod(M)                       # states x states; diag = richness
shared_mat <- as.matrix(shared)
states <- rownames(shared_mat)

# upper triangle -> long unordered pairs (StateA < StateB)
ut <- which(upper.tri(shared_mat), arr.ind = TRUE)
state_pairs <- tibble(
  StateA = states[ut[, "row"]],
  StateB = states[ut[, "col"]],
  n      = shared_mat[ut]
) %>% filter(n > 0) %>% arrange(StateA, StateB)

# --- provenance metadata ------------------------------------------------------
meta <- list(
  states     = sort(unique(slim$State)),   # picker choices -- every one has data
  n_states   = n_distinct(slim$State),
  n_species  = n_distinct(slim$symbol),
  n_raw_rows = nrow(raw),
  source     = "USDA PLANTS database (state checklists), filtered to movie-biome families",
  built_at   = format(Sys.time(), "%Y-%m-%d %H:%M %Z")
)

# --- write --------------------------------------------------------------------
saveRDS(biome_tally,        file.path(out_dir, "biome_tally.rds"),        compress = "xz")
saveRDS(state_biome_family, file.path(out_dir, "state_biome_family.rds"), compress = "xz")
saveRDS(state_pairs,        file.path(out_dir, "state_pairs.rds"),        compress = "xz")
saveRDS(biome_pool,         file.path(out_dir, "biome_pool.rds"),         compress = "xz")
saveRDS(biome_totals,       file.path(out_dir, "biome_totals.rds"),       compress = "xz")
saveRDS(state_richness,     file.path(out_dir, "state_richness.rds"),     compress = "xz")
saveRDS(meta,               file.path(out_dir, "meta.rds"),               compress = "xz")

# --- report -------------------------------------------------------------------
arts <- list.files(out_dir, pattern = "\\.rds$", full.names = TRUE)
total <- sum(file.info(arts)$size)
message("\nWrote ", length(arts), " artifacts to ", out_dir, "/ :")
for (a in arts) message(sprintf("  %-26s %8.1f KB", basename(a), file.info(a)$size / 1024))
message(sprintf("  %-26s %8.1f KB", "TOTAL", total / 1024))
message(sprintf("  (raw CSV was %.1f MB -> %.1f%% reduction)",
                file.info(csv_path)$size / 1024^2,
                100 * (1 - total / file.info(csv_path)$size)))
