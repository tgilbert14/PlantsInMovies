# R/biomes.R
# ------------------------------------------------------------------------------
# Single source of truth for the movie-biome -> plant-family mapping.
# Sourced by BOTH scripts/precompute.R (to build the data bundle) and app.R
# (for the methodology modal + display metadata). Keeping it in one place means
# the family lists, display names, and colors can never drift between the data
# that is computed and the text the user is shown.
# ------------------------------------------------------------------------------

# Families chosen to evoke each movie world's flora. NOT a phylogenetic claim --
# these are hand-curated, whimsical groupings (see methodology disclosure in app).
BIOME_FAMILIES <- list(
  # Jurassic Park / Isla Nublar -- ferns, conifers, horsetails, ancient lineages
  "Isla Nublar" = c(
    "Araucariaceae", "Aspleniaceae", "Blechnaceae", "Cupressaceae", "Cyatheaceae",
    "Cycadaceae", "Dennstaedtiaceae", "Dryopteridaceae", "Equisetaceae",
    "Ginkgoaceae", "Isoetaceae", "Marattiaceae", "Ophioglossaceae", "Osmundaceae",
    "Pinaceae", "Podocarpaceae", "Polypodiaceae", "Psilotaceae", "Pteridaceae",
    "Selaginellaceae", "Thelypteridaceae", "Zamiaceae"
  ),
  # Dune / Arrakis -- succulents, desert plants, grasses, drought-adapted families
  "Arrakis" = c(
    "Agavaceae", "Aizoaceae", "Amaranthaceae", "Anacardiaceae", "Asparagaceae",
    "Brassicaceae", "Burseraceae", "Cactaceae", "Fouquieriaceae", "Frankeniaceae",
    "Poaceae", "Polygonaceae", "Tamaricaceae", "Zygophyllaceae"
  ),
  # Lord of the Rings / Middle-earth -- cool forest & alpine families
  "Middle-earth" = c(
    "Apiaceae", "Araliaceae", "Asteraceae", "Betulaceae", "Cornaceae", "Ericaceae",
    "Fagaceae", "Gentianaceae", "Hydrangeaceae", "Juglandaceae", "Primulaceae",
    "Ranunculaceae", "Rosaceae", "Salicaceae", "Saxifragaceae"
  )
)

# Display metadata for each biome: the movie it evokes and the chord/gauge color.
BIOME_META <- list(
  "Arrakis"      = list(movie = "Dune",          color = "#E8A33D"),
  "Middle-earth" = list(movie = "Lord of the Rings", color = "#4FA86B"),
  "Isla Nublar"  = list(movie = "Jurassic Park", color = "#3FB9C9")
)

BIOME_NAMES <- names(BIOME_FAMILIES)

# Long lookup table: Family -> Movie (biome). One row per family.
BIOME_LOOKUP <- do.call(rbind, lapply(BIOME_NAMES, function(b) {
  data.frame(Family = BIOME_FAMILIES[[b]], Movie = b, stringsAsFactors = FALSE)
}))

# Assign a vector of family names to their biome, or NA if unmapped.
assign_biome <- function(family) {
  BIOME_LOOKUP$Movie[match(family, BIOME_LOOKUP$Family)]
}
