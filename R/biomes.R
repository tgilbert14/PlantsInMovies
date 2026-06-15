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

# Display metadata for each biome -- the single source of truth shared by the
# bar chart, the KPI value boxes, the chord, and the family pills. "Herbarium"
# palette: three jewel-toned botanical-plate accents on ivory paper.
#   color = saturated accent | soft = tint for fills | dark = readable text on soft
#   icon  = bsicons name used in value boxes / accordion / hero specimen row
BIOME_META <- list(
  "Arrakis"      = list(movie = "Dune",              color = "#C9852A",
                        soft = "#F3E4CB", dark = "#8A5A14", icon = "sun"),
  "Middle-earth" = list(movie = "Lord of the Rings", color = "#3F7A52",
                        soft = "#DDE9DD", dark = "#2C5A3A", icon = "tree"),
  "Isla Nublar"  = list(movie = "Jurassic Park",     color = "#2E8A99",
                        soft = "#D6E8EA", dark = "#1F6470", icon = "droplet")
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
