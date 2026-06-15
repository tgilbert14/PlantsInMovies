# R/charts.R
# ------------------------------------------------------------------------------
# The interactive "flora match" chart (ggiraph) -- "Herbarium" light theme.
# One horizontal-bar facet per movie biome, one bar per selected state, with
# hover/tap tooltips that reveal the per-family breakdown -- so the family-size
# confound (e.g. Asteraceae = 65% of a state's "Middle-earth" score) is visible
# right in the interaction. A Raw/Fair-share toggle switches the metric.
# Depends on BIOME_FAMILIES / BIOME_META from R/biomes.R.
# ------------------------------------------------------------------------------

suppressMessages({
  library(ggplot2)
  library(ggiraph)
  library(dplyr)
})

# Facet order + display: biome -> "Arrakis\nDune" etc.
.biome_order  <- c("Arrakis", "Middle-earth", "Isla Nublar")
.biome_film   <- vapply(.biome_order, function(m) BIOME_META[[m]]$movie, character(1))
.biome_color  <- vapply(names(BIOME_META), function(m) BIOME_META[[m]]$color, character(1))
# two-line strip ("Arrakis\nDune") so long film names don't clip the panel edge
.biome_strip  <- setNames(sprintf("%s\n%s", .biome_order, .biome_film), .biome_order)

# "Herbarium" paper palette (kept here so the chart is self-contained)
.pal <- list(
  paper = "#FBF8F1", grid = "#E4DAC6", ink = "#22201C", text = "#33302A",
  axis = "#6E665A", strip_bg = "#EFE8DA"
)

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

# Best-matching state per biome under a given metric (drives the KPI value boxes).
best_per_biome <- function(tbl, mode = c("raw", "fair")) {
  mode <- match.arg(mode)
  tbl$value <- if (mode == "fair") tbl$fair else tbl$n
  tbl %>%
    group_by(Movie) %>%
    slice_max(value, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(Movie = as.character(Movie), State = as.character(State),
              n, fair, value)
}

.theme_movie <- function() {
  theme_minimal(base_size = 13) +
    theme(
      plot.background    = element_rect(fill = .pal$paper, color = NA),
      panel.background   = element_rect(fill = .pal$paper, color = NA),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_line(color = .pal$grid, linewidth = 0.3),
      panel.spacing      = unit(14, "pt"),
      text       = element_text(color = .pal$text),
      axis.text  = element_text(color = .pal$axis),
      axis.title = element_text(color = .pal$axis),
      strip.background = element_rect(fill = .pal$strip_bg, color = NA),
      strip.text = element_text(color = .pal$ink, face = "bold", size = 12.5),
      legend.position = "none"
    )
}

# Build the ggiraph object. mode: "raw" species counts | "fair" % of national pool.
build_match_girafe <- function(tbl, mode = c("raw", "fair"), width_svg = 8.5) {
  mode <- match.arg(mode)
  tbl$value <- if (mode == "fair") tbl$fair else tbl$n
  xlab <- if (mode == "fair") "Share of that world's flora found in the state (%)"
          else                "Unique species the state has in that world's families"

  # accent only the leading (max) label per world -- draws the eye to the answer
  tbl <- tbl %>% group_by(Movie) %>%
    mutate(is_max = value > 0 & value == max(value)) %>% ungroup()
  tbl$label_color <- ifelse(tbl$is_max, .biome_color[tbl$Movie], .pal$text)

  tbl$tooltip <- sprintf(
    paste0("<b style='font-size:13px'>%s</b><br>",
           "<span style='color:%s'>&#9679;</span> %s &mdash; <i>%s</i><br>",
           "<b>%s</b> species &nbsp;|&nbsp; <b>%s%%</b> of this world's flora<br>",
           "<span style='color:#6E665A'>Top families:</span><br>&nbsp;&nbsp;%s"),
    tbl$State, .biome_color[tbl$Movie], tbl$Movie, tbl$film,
    formatC(tbl$n, big.mark = ",", format = "d"), tbl$fair, tbl$top)

  n_states <- nlevels(tbl$State)
  lab_value <- if (mode == "fair") paste0(tbl$value, "%") else
               formatC(tbl$value, big.mark = ",", format = "d")

  p <- ggplot(tbl, aes(x = value, y = State, fill = Movie)) +
    geom_col_interactive(
      aes(tooltip = tooltip, data_id = interaction(State, Movie)),
      width = 0.72) +
    geom_text(aes(label = ifelse(value > 0, lab_value, ""), color = label_color),
              hjust = -0.12, size = 3.0) +
    facet_wrap(~Movie_lab, nrow = 1) +
    scale_fill_manual(values = .biome_color) +
    scale_color_identity() +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(x = xlab, y = NULL) +
    .theme_movie()

  png_name <- if (mode == "fair") "flora-match-fair" else "flora-match-raw"

  girafe(
    ggobj = p,
    width_svg = width_svg,
    height_svg = max(2.4, 0.42 * n_states + 1.2),
    options = list(
      opts_tooltip(css = paste0("background-color:#FBF8F1;color:#33302A;",
                                "border:1px solid #DAD0BE;border-radius:8px;",
                                "padding:10px 12px;font-family:'Source Sans 3',Arial,sans-serif;",
                                "box-shadow:0 6px 20px rgba(34,32,28,.12);"),
                   opacity = 0.98, delay_mouseout = 800),
      opts_hover(css = "stroke:#22201C;stroke-width:1.2px;cursor:pointer;"),
      opts_hover_inv(css = "opacity:0.3;"),
      opts_selection(type = "none"),
      opts_sizing(rescale = TRUE),
      opts_toolbar(saveaspng = TRUE, position = "topright", pngname = png_name)
    )
  )
}

# Empty-state placeholder rendered through the SAME girafe path (no blank panel).
empty_girafe <- function(msg = "Select one or more states, then tap Create / Refresh.",
                         width_svg = 8.5) {
  p <- ggplot() +
    annotate("text", x = 0, y = 0, label = msg, color = .pal$axis, size = 4.2) +
    theme_void() +
    theme(plot.background  = element_rect(fill = .pal$paper, color = NA),
          panel.background = element_rect(fill = .pal$paper, color = NA))
  girafe(ggobj = p, width_svg = width_svg, height_svg = 1.8,
         options = list(opts_sizing(rescale = TRUE), opts_toolbar(saveaspng = FALSE)))
}
