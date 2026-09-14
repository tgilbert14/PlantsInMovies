# R/charts.R
# ------------------------------------------------------------------------------
# The interactive "flora match" chart (ggiraph) -- Botanical Cinema theme.
# One horizontal-bar facet per movie biome, one bar per selected state, with
# hover/tap tooltips that reveal the per-family breakdown -- so the family-size
# confound (e.g. Asteraceae = 65% of a state's "Middle-earth" score) is visible
# right in the interaction. Raw and national-pool views share the same counts.
# Depends on BIOME_FAMILIES / BIOME_META from R/biomes.R.
# ------------------------------------------------------------------------------

suppressMessages({
  library(ggplot2)
  library(ggiraph)
  library(dplyr)
})

# Facet order + display: biome -> "Arrakis\nDune" etc. Explicit names keep
# character indexing reliable even if the metadata list is reordered later.
.biome_order <- c("Arrakis", "Middle-earth", "Isla Nublar")
.biome_film <- setNames(
  vapply(.biome_order, function(m) BIOME_META[[m]]$movie, character(1), USE.NAMES = FALSE),
  .biome_order
)
.biome_color <- setNames(
  vapply(.biome_order, function(m) BIOME_META[[m]]$color, character(1), USE.NAMES = FALSE),
  .biome_order
)
# two-line strip ("Arrakis\nDune") so long film names don't clip the panel edge
.biome_strip  <- setNames(sprintf("%s\n%s", .biome_order, .biome_film), .biome_order)

# Quiet Botanical Cinema paper palette (world colors remain in BIOME_META).
.pal <- list(
  field = "#F3EDDD", paper = "#FBF8F1", grid = "#DED4C0", rule = "#D2C6AF",
  ink = "#253028", text = "#344139", axis = "#657068", strip_bg = "#F3EDDD"
)

# Build the plot table for the selected states (all state x biome cells, 0-filled).
build_match_table <- function(sel, biome_tally, biome_totals,
                              state_biome_family, state_richness) {
  grid <- expand.grid(State = sel, Movie = .biome_order, stringsAsFactors = FALSE)

  tbl <- grid %>%
    left_join(biome_tally, by = c("State", "Movie")) %>%
    mutate(n = tidyr::replace_na(n, 0L)) %>%
    left_join(biome_totals, by = "Movie") %>%
    mutate(fair = ifelse(pool_us == 0, 0, round(100 * n / pool_us, 1)))

  # top-3 contributing families per (state, biome) for the tooltip
  fam <- state_biome_family %>%
    filter(State %in% sel) %>%
    group_by(State, Movie) %>%
    arrange(desc(n), .by_group = TRUE) %>%
    mutate(tot = sum(n), pct = ifelse(tot == 0, 0, round(100 * n / tot))) %>%
    slice_head(n = 3) %>%
    summarise(top = paste0(Family, " · ", n, " (", pct, "%)",
                           collapse = "<br>&nbsp;&nbsp;"),
              .groups = "drop")

  tbl <- tbl %>% left_join(fam, by = c("State", "Movie"))
  tbl$top[is.na(tbl$top)] <- "&mdash;"

  # consistent state order across facets: by overall in-biome richness
  ord <- state_richness %>% filter(State %in% sel) %>%
    arrange(total_species) %>% pull(State)
  ord <- c(setdiff(sel, ord), ord)        # any with no richness sink to bottom
  tbl$State    <- factor(tbl$State, levels = ord)
  tbl$film <- unname(.biome_film[as.character(tbl$Movie)])
  tbl$Movie_lab <- factor(
    unname(.biome_strip[as.character(tbl$Movie)]),
    levels = unname(.biome_strip[.biome_order])
  )
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

.theme_movie <- function(stacked = FALSE) {
  theme_minimal(base_size = 13) +
    theme(
      plot.background    = element_rect(fill = .pal$field, color = NA),
      panel.background   = element_rect(fill = .pal$paper, color = NA),
      panel.border       = element_rect(fill = NA, color = .pal$rule, linewidth = 0.35),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_line(color = .pal$grid, linewidth = 0.32),
      panel.spacing      = grid::unit(if (isTRUE(stacked)) 18 else 14, "pt"),
      text       = element_text(color = .pal$text),
      axis.text.x = element_text(color = .pal$axis,
                                 size = if (isTRUE(stacked)) 10 else 9.5),
      axis.text.y = element_text(color = .pal$ink,
                                 size = if (isTRUE(stacked)) 11.5 else 10.5),
      axis.title.x = element_text(color = .pal$axis, size = 10.5,
                                  margin = margin(t = 9)),
      strip.background = element_rect(fill = .pal$strip_bg, color = .pal$rule,
                                      linewidth = 0.35),
      strip.text = element_text(color = .pal$ink, face = "bold",
                                size = if (isTRUE(stacked)) 12.5 else 12,
                                lineheight = 0.94, margin = margin(7, 5, 7, 5)),
      plot.caption = element_text(color = .pal$axis, size = 9, hjust = 0,
                                  margin = margin(t = 8)),
      plot.margin = margin(10, 16, 10, 12),
      legend.position = "none"
    )
}

# Build the ggiraph object. mode: "raw" symbol counts | "fair" % of national
# pool. `stacked = TRUE` gives each world the full plot width on narrow screens.
build_match_girafe <- function(tbl, mode = c("raw", "fair"), width_svg = 8.5,
                               stacked = FALSE) {
  mode <- match.arg(mode)
  stacked <- isTRUE(stacked)

  if (is.null(tbl) || nrow(tbl) == 0) {
    return(empty_girafe("No states are available to compare.", width_svg = width_svg))
  }

  tbl$value <- if (mode == "fair") tbl$fair else tbl$n
  tbl$value[!is.finite(tbl$value)] <- 0
  xlab <- if (mode == "fair") "National pool (%)"
          else                "Unique plant records (USDA symbols)"

  # accent only the leading (max) label per world -- draws the eye to the answer
  tbl <- tbl %>% group_by(Movie) %>%
    mutate(is_max = value > 0 & value == max(value)) %>% ungroup()
  tbl$label_color <- ifelse(
    tbl$is_max,
    unname(.biome_color[as.character(tbl$Movie)]),
    .pal$text
  )

  tbl$tooltip <- sprintf(
    paste0("<b style='font-size:13px'>%s</b><br>",
           "<span style='color:%s'>&#9679;</span> %s · <i>%s</i><br>",
           "<b>%s</b> unique plant records <span style='color:#657068'>(USDA symbols)</span><br>",
           "<b>National pool:</b> %s%% <span style='color:#657068'>(state symbols ÷ national symbols for this world)</span><br>",
           "<span style='color:#657068'>Largest family contributions:</span><br>&nbsp;&nbsp;%s<br>",
           "<span style='color:#657068;font-size:11px'>National pool (%%) does not adjust for state size or family-size bias.</span>"),
    tbl$State, unname(.biome_color[as.character(tbl$Movie)]), tbl$Movie, tbl$film,
    formatC(as.integer(tbl$n), big.mark = ",", format = "d"),
    formatC(tbl$fair, format = "f", digits = 1), tbl$top)

  n_states <- max(1L, dplyr::n_distinct(as.character(tbl$State)))
  n_facets <- max(1L, dplyr::n_distinct(as.character(tbl$Movie_lab)))
  all_zero <- !any(tbl$value > 0, na.rm = TRUE)
  lab_value <- if (mode == "fair") {
    paste0(formatC(tbl$value, format = "f", digits = 1), "%")
  } else {
    formatC(as.integer(tbl$value), big.mark = ",", format = "d")
  }
  value_label <- if (all_zero) lab_value else ifelse(tbl$value > 0, lab_value, "")
  x_limits <- if (all_zero) c(0, 1) else NULL
  x_breaks <- if (all_zero) 0 else waiver()
  zero_caption <- if (all_zero) "No matching plant records for these states." else NULL
  facets <- if (stacked) {
    facet_wrap(~Movie_lab, ncol = 1)
  } else {
    facet_wrap(~Movie_lab, nrow = 1)
  }

  p <- ggplot(tbl, aes(x = value, y = State, fill = Movie)) +
    geom_col_interactive(
      aes(tooltip = tooltip, data_id = interaction(State, Movie)),
      width = 0.72) +
    geom_text(aes(label = value_label, color = label_color),
              hjust = -0.12, size = if (stacked) 3.25 else 3.0) +
    facets +
    scale_fill_manual(values = .biome_color) +
    scale_color_identity() +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18)),
                       limits = x_limits, breaks = x_breaks) +
    labs(x = xlab, y = NULL, caption = zero_caption) +
    .theme_movie(stacked = stacked)

  png_name <- if (mode == "fair") "flora-match-national-pool" else "flora-match-raw"
  height_svg <- if (stacked) {
    max(4.9, n_facets * max(1.6, 0.36 * n_states + 1.0))
  } else {
    max(2.5, 0.42 * n_states + 1.25)
  }

  girafe(
    ggobj = p,
    width_svg = width_svg,
    height_svg = height_svg,
    options = list(
      opts_tooltip(css = paste0("background-color:#FBF8F1;color:#253028;",
                                "border:1px solid #D2C6AF;border-radius:8px;",
                                "padding:10px 12px;font-family:'Source Sans 3',Arial,sans-serif;",
                                "box-shadow:0 6px 20px rgba(37,48,40,.14);"),
                   opacity = 0.98, delay_mouseout = 800),
      opts_hover(css = "stroke:#253028;stroke-width:1.2px;cursor:pointer;"),
      opts_hover_inv(css = "opacity:0.32;"),
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
    theme(plot.background  = element_rect(fill = .pal$field, color = NA),
          panel.background = element_rect(fill = .pal$paper, color = NA))
  girafe(ggobj = p, width_svg = width_svg, height_svg = 1.8,
         options = list(opts_sizing(rescale = TRUE), opts_toolbar(saveaspng = FALSE)))
}
