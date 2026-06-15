# R/charts.R
# ------------------------------------------------------------------------------
# The interactive "flora match" chart (ggiraph). Replaces the plotly gauges:
# one horizontal-bar panel per movie biome, one bar per selected state, with
# hover tooltips that reveal the per-family breakdown -- so the family-size
# confound (e.g. Asteraceae = 65% of a state's "Middle-earth" score) is visible
# right in the interaction. A Raw/Fair-share toggle switches the metric.
# Depends on BIOME_FAMILIES / BIOME_META from R/biomes.R.
# ------------------------------------------------------------------------------

suppressMessages({
  library(ggplot2)
  library(ggiraph)
  library(dplyr)
})

# Facet order + display: biome -> "Arrakis\n(Dune)" etc.
.biome_order  <- c("Arrakis", "Middle-earth", "Isla Nublar")
.biome_film   <- vapply(.biome_order, function(m) BIOME_META[[m]]$movie, character(1))
.biome_color  <- vapply(names(BIOME_META), function(m) BIOME_META[[m]]$color, character(1))
# two-line strip ("Arrakis\nDune") so long film names don't clip the panel edge
.biome_strip  <- setNames(sprintf("%s\n%s", .biome_order, .biome_film), .biome_order)

# Build the plot table for the selected states (all state x biome cells, 0-filled).
build_match_table <- function(sel, biome_tally, biome_totals,
                              state_biome_family, state_richness) {
  grid <- expand.grid(State = sel, Movie = .biome_order, stringsAsFactors = FALSE)

  tbl <- grid %>%
    left_join(biome_tally, by = c("State", "Movie")) %>%
    mutate(n = tidyr::replace_na(n, 0L)) %>%
    left_join(biome_totals, by = "Movie") %>%
    mutate(fair = round(100 * n / pool_us, 1))

  # top-3 contributing families per (state, biome) for the tooltip
  fam <- state_biome_family %>%
    filter(State %in% sel) %>%
    group_by(State, Movie) %>%
    arrange(desc(n), .by_group = TRUE) %>%
    mutate(tot = sum(n), pct = round(100 * n / tot)) %>%
    slice_head(n = 3) %>%
    summarise(top = paste0(Family, " &mdash; ", n, " (", pct, "%)",
                           collapse = "<br>&nbsp;&nbsp;"),
              .groups = "drop")

  tbl <- tbl %>% left_join(fam, by = c("State", "Movie"))
  tbl$top[is.na(tbl$top)] <- "&mdash;"

  # consistent state order across facets: by overall in-biome richness
  ord <- state_richness %>% filter(State %in% sel) %>%
    arrange(total_species) %>% pull(State)
  ord <- c(setdiff(sel, ord), ord)        # any with no richness sink to bottom
  tbl$State    <- factor(tbl$State, levels = ord)
  tbl$film     <- .biome_film[tbl$Movie]
  tbl$Movie_lab <- factor(.biome_strip[tbl$Movie], levels = .biome_strip[.biome_order])
  tbl
}

.theme_movie <- function() {
  theme_minimal(base_size = 13) +
    theme(
      plot.background   = element_rect(fill = "#151515", color = NA),
      panel.background  = element_rect(fill = "#151515", color = NA),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_line(color = "#333333", linewidth = 0.3),
      panel.spacing      = unit(14, "pt"),
      text       = element_text(color = "#e8e8e8"),
      axis.text  = element_text(color = "#cfcfcf"),
      axis.title = element_text(color = "#bdbdbd"),
      strip.text = element_text(color = "#ffffff", face = "bold", size = 12.5),
      plot.title = element_text(color = "#ffffff", face = "bold", size = 15),
      plot.subtitle = element_text(color = "#9aa0a6", size = 10.5),
      legend.position = "none"
    )
}

# Build the ggiraph object. mode: "raw" species counts | "fair" % of national pool.
build_match_girafe <- function(tbl, mode = c("raw", "fair"),
                               width_svg = 8.5) {
  mode <- match.arg(mode)
  tbl$value <- if (mode == "fair") tbl$fair else tbl$n
  xlab <- if (mode == "fair") "Share of that world's flora found in the state (%)"
          else                "Unique species the state has in that world's families"
  sub  <- if (mode == "fair")
            "Fair share — each state measured against the same national pool per world (removes family-size bias)."
          else
            "Raw counts — favors big, species-rich states & large plant families. Hover to see which families dominate."

  tbl$tooltip <- sprintf(
    paste0("<b style='font-size:13px'>%s</b><br>",
           "<span style='color:%s'>●</span> %s &mdash; <i>%s</i><br>",
           "<b>%s</b> species &nbsp;|&nbsp; <b>%s%%</b> of this world's flora<br>",
           "<span style='color:#9aa0a6'>Top families:</span><br>&nbsp;&nbsp;%s"),
    tbl$State, .biome_color[tbl$Movie], tbl$Movie, tbl$film,
    formatC(tbl$n, big.mark = ",", format = "d"), tbl$fair, tbl$top)

  n_states <- nlevels(tbl$State)
  lab_value <- if (mode == "fair") paste0(tbl$value, "%") else
               formatC(tbl$value, big.mark = ",", format = "d")

  p <- ggplot(tbl, aes(x = value, y = State, fill = Movie)) +
    geom_col_interactive(
      aes(tooltip = tooltip, data_id = interaction(State, Movie)),
      width = 0.72) +
    geom_text(aes(label = ifelse(value > 0, lab_value, "")),
              hjust = -0.12, size = 3.1, color = "#e8e8e8") +
    facet_wrap(~Movie_lab, nrow = 1) +
    scale_fill_manual(values = .biome_color) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(title = "How well does each state's flora match each movie world?",
         subtitle = sub, x = xlab, y = NULL) +
    .theme_movie()

  girafe(
    ggobj = p,
    width_svg = width_svg,
    height_svg = max(2.4, 0.42 * n_states + 1.4),
    options = list(
      opts_tooltip(css = paste0("background-color:#0b0b0b;color:#f1f1f1;",
                                "border:1px solid #444;border-radius:6px;",
                                "padding:8px 10px;font-family:Arial;",
                                "box-shadow:0 2px 8px rgba(0,0,0,.5);"),
                   opacity = 0.97),
      opts_hover(css = "stroke:#ffffff;stroke-width:1.4px;cursor:pointer;"),
      opts_hover_inv(css = "opacity:0.35;"),
      opts_sizing(rescale = TRUE),
      opts_toolbar(saveaspng = TRUE, position = "topright",
                   pngname = "flora-match")
    )
  )
}
