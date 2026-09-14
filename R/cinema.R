# Botanical Cinema: presentation helpers. Curated mappings and data stay in biomes.R.
WORLD_STYLE <- list(
  Arrakis = list(id = "arrakis", tone = "#E9AD68", title = "Desert in the frame.",
                 description = "Grasses, cactuses and other families chosen to evoke Dune's desert world.", subtitle = "Desert & succulent families"),
  `Middle-earth` = list(id = "middleearth", tone = "#BBD277", title = "A world of woodland.",
                 description = "Forest and alpine families chosen to evoke the landscapes of Middle-earth.", subtitle = "Forest & alpine families"),
  `Isla Nublar` = list(id = "islanublar", tone = "#99D4CE", title = "Into the fern forest.",
                 description = "Ferns, conifers and other lineages chosen to evoke Jurassic Park.", subtitle = "Ferns, conifers & cycads")
)
fmt <- function(x) formatC(x, format = "d", big.mark = ",")
world_art <- function(world, class = "") {
  tags$img(src = paste0("cinema/", WORLD_STYLE[[world]]$id, "-v1.svg"),
           alt = "", class = paste("botanical-art", class), width = 600, height = 440)
}
world_buttons <- function() {
  div(class = "world-strip", role = "group", `aria-label` = "Choose a movie world",
      lapply(names(WORLD_STYLE), function(w) {
        st <- WORLD_STYLE[[w]]
        tags$button(type = "button", class = "world-button", `data-world` = w,
                    `aria-pressed` = if (w == "Arrakis") "true" else "false",
                    style = paste0("--world-tone:", st$tone),
                    world_art(w), span(class = "world-button-copy", span(class = "film-label", BIOME_META[[w]]$movie),
                     span(class = "world-name", w), span(class = "world-subtitle", st$subtitle)),
                    span(class = "selected-mark", `aria-hidden` = "true", "↗"))
      }))
}
# A shared function keeps the screen and actual PNG download identical.
draw_cinema_chord <- function(edges, with_names = TRUE, title = NULL, show_axis = TRUE) {
  par(bg = "#F3EDDD", mar = c(1, 1, if (is.null(title)) 1 else 3.8, 1), fg = "#253028", col = "#253028")
  on.exit(circos.clear(), add = TRUE)
  if (is.null(edges) || !nrow(edges) || !any(edges$n > 0)) {
    plot.new(); text(.5, .5, "Choose states to compare their plant records.", col = "#253028", cex = .9)
    return(invisible())
  }
  st <- sort(setdiff(unique(c(edges$Movie, edges$State)), names(BIOME_META)))
  colors <- setNames(colorRampPalette(c("#B7C3A4", "#455A46"))(max(1,length(st))), st)
  world_colors <- vapply(BIOME_META, `[[`, character(1), "color")
  circos.par(gap.after = 4, canvas.xlim = c(-1.2, 1.2), canvas.ylim = c(-1.2, 1.2))
  chordDiagram(edges, annotationTrack = if(show_axis) c("grid", "axis") else "grid",
               grid.col = c(world_colors, colors), grid.border = NA,
               transparency = .35, link.sort = TRUE, link.decreasing = TRUE,
               preAllocateTracks = list(track.height = .15))
  if (with_names) circos.trackPlotRegion(track.index = 1, panel.fun = function(x,y) {
    circos.text(CELL_META$xcenter, CELL_META$ylim[2], CELL_META$sector.index,
                facing = "clockwise", niceFacing = TRUE, adj = c(0,.5), cex = .64, col = "#253028")
  }, bg.border = NA)
  if (!is.null(title)) {
    title(main = title, cex.main = 1.15, col.main = "#253028")
    mtext("USDA plant records · curated movie-world families · Plants in Movies", side = 1, line = -.5, cex = .62, col = "#485544")
  }
}

selection_slug <- function(states) {
  if (!length(states)) return("no-places")
  base <- paste(gsub("[^a-z0-9]+", "-", tolower(head(states, 3))), collapse="-")
  if (length(states)>3) paste0(base,"-plus-",length(states)-3) else base
}
