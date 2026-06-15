library(shiny)
library(bslib)
library(bsicons)
library(waiter)
library(shinyjs)
library(dplyr)
library(tidyr)
library(circlize)
library(ggplot2)
library(ggiraph)

# ------------------------------------------------------------------------------
# Data: load the precomputed bundle (~11 KB) instead of the 32 MB raw CSV.
# Rebuild it with: Rscript scripts/precompute.R  (after any data refresh).
# ------------------------------------------------------------------------------
source("R/biomes.R")
source("R/charts.R")
biome_tally        <- readRDS("data/biome_tally.rds")        # State x Movie -> n
biome_totals       <- readRDS("data/biome_totals.rds")       # Movie -> national pool
state_biome_family <- readRDS("data/state_biome_family.rds") # State x Movie x Family -> n
state_richness     <- readRDS("data/state_richness.rds")     # State -> total species
state_pairs        <- readRDS("data/state_pairs.rds")        # StateA x StateB -> shared
meta               <- readRDS("data/meta.rds")               # provenance + picker states

picker_states <- meta$states  # every option has data behind it (incl. Puerto Rico, no Rhode Island)

# ---- static copy -------------------------------------------------------------
method_html <- HTML(
  "<p>For each state we count the unique plant species whose family belongs to a
  movie world's curated family list. <b>Raw species counts</b> show those totals;
  <b>Fair share</b> divides by the number of such species nationwide, so small and
  large states can be compared fairly &mdash; it removes the advantage big,
  species-rich states and giant plant families would otherwise have.</p>")

caveat_html <- HTML(
  "<b>Read me:</b> raw counts favor big, species-rich states and large plant
  families &mdash; e.g. <i>Asteraceae</i> (the daisy family, the largest on Earth)
  alone is ~65% of Arizona's &ldquo;Middle-earth&rdquo; score. Switch to
  <b>Fair share</b> to measure each state against the same national species pool
  per world, and <b>tap any bar</b> to see which families are doing the work.
  These biome groupings are a playful curation, not a phylogenetic claim.")

chord_caption_html <- HTML(
  "Cord width is the number of species shared. Following a cord from a movie world
  to a state shows how many species they share; cords between two states show
  species that occur in both. The fattest cords are drawn on top.")

# family-pill list for one biome (accordion panel body)
fam_pills <- function(biome) {
  cls <- c("Arrakis" = "arrakis", "Middle-earth" = "middleearth",
           "Isla Nublar" = "islanublar")[[biome]]
  div(lapply(BIOME_FAMILIES[[biome]],
             function(f) span(class = paste("fam-pill", cls), f)))
}

# First-visit welcome: a small head script reports whether this browser has seen
# it (localStorage) and stores the flag when asked, so the modal shows only once.
welcome_js <- HTML(
  "document.addEventListener('DOMContentLoaded', function() {
     $(document).on('shiny:connected', function() {
       if (!window.__pim_welcome_handler) {
         Shiny.addCustomMessageHandler('pim_mark_welcome', function(x) {
           try { localStorage.setItem('pim_seen_welcome', '1'); } catch(e) {}
         });
         window.__pim_welcome_handler = true;
       }
       var seen = false;
       try { seen = localStorage.getItem('pim_seen_welcome') === '1'; } catch(e) {}
       Shiny.setInputValue('seen_welcome', seen, {priority: 'event'});
     });
   });")

welcome_modal <- function() {
  modalDialog(
    title = NULL, easyClose = TRUE, fade = TRUE,
    footer = actionButton("dismiss_welcome", "Press onward →",
                          class = "btn-primary"),
    div(
      div(style = paste0("height:3px;width:140px;margin:2px auto 16px;background:",
          "linear-gradient(90deg,#C9852A 0 33.3%,#3F7A52 33.3% 66.6%,#2E8A99 66.6% 100%);")),
      h3(class = "text-center",
         style = "font-family:'Fraunces',Georgia,serif;color:#22201C;margin-top:0;",
         "Welcome to the field guide"),
      p(class = "text-center text-muted",
        "Which U.S. state's flora best matches each movie world?"),
      p(HTML("Three worlds, each a curated set of plant families:
        <span style='color:#C9852A'><b>Arrakis</b></span> (Dune &mdash; desert &amp;
        succulent), <span style='color:#3F7A52'><b>Middle-earth</b></span> (LOTR
        &mdash; cool forest &amp; alpine), and
        <span style='color:#2E8A99'><b>Isla Nublar</b></span> (Jurassic Park
        &mdash; ancient ferns &amp; conifers).")),
      tags$ul(
        tags$li(HTML("<b>Pick states</b> on the left &mdash; the bar chart ranks how
                     well each one's flora fits each world.")),
        tags$li(HTML("<b>Tap any bar</b> to see which plant families drive the score.")),
        tags$li(HTML("Toggle <b>Raw counts &rarr; Fair share</b> to compare big and
                     small states fairly.")),
        tags$li(HTML("The <b>chord map</b> shows the species each state shares with
                     every world &mdash; and with the other states."))
      ),
      p(class = "text-muted small mb-0",
        "These groupings are a playful curation, not a phylogenetic claim — which is
        exactly why Fair share matters.")
    )
  )
}

# ---- theme -------------------------------------------------------------------
herbarium_theme <- bs_theme(
  version = 5,
  bg = "#FBF8F1", fg = "#33302A",
  primary = "#3F7A52", secondary = "#6E665A", success = "#3F7A52",
  info = "#2E8A99", warning = "#C9852A", danger = "#9A3B2E",
  base_font    = font_google("Source Sans 3", local = FALSE),
  heading_font = font_google("Fraunces", local = FALSE),
  "border-radius" = "0.6rem",
  "card-border-color" = "#DAD0BE"
) |>
  bs_add_rules(sass::sass_file("www/herbarium.scss"))

# ---- hero masthead -----------------------------------------------------------
hero <- div(
  class = "pim-hero",
  div(
    class = "pim-hero-bar",
    div(
      p(class = "pim-kicker", "A FIELD GUIDE"),
      h1("Plants in Movies"),
      p(class = "pim-subtitle",
        "Which US state's flora best matches each movie world?"),
      div(class = "pim-specimen-row",
          bs_icon("sun"), bs_icon("tree"), bs_icon("droplet"))
    ),
    div(input_dark_mode(id = "dark_mode", mode = "light"))
  )
)

ui <- page_fluid(
  theme = herbarium_theme,
  useShinyjs(),
  useWaiter(),
  tags$head(tags$script(welcome_js)),
  waiter_show_on_load(
    color = "#F4EFE6",
    html = tagList(
      div(style = "font-family:'Fraunces',Georgia,serif;font-size:34px;color:#22201C;",
          "Herbarium"),
      div(style = paste0("height:3px;width:180px;margin:14px auto;background:",
          "linear-gradient(90deg,#C9852A 0 33.3%,#3F7A52 33.3% 66.6%,#2E8A99 66.6% 100%);")),
      div(style = "color:#6E665A;font-family:Arial,sans-serif;margin-top:6px;",
          "Pressing the specimens…")
    )
  ),
  hero,
  layout_sidebar(
    sidebar = sidebar(
      width = 320,
      open = list(desktop = "open", mobile = "closed"),
      card(
        card_header("Select specimens"),
        selectizeInput("state", label = NULL, choices = picker_states,
                       selected = c("Arizona", "California", "Maine"),
                       multiple = TRUE),
        actionButton("click_state", "Create / Refresh",
                     icon = bs_icon("arrow-repeat"), class = "btn-primary w-100")
      ),
      accordion(
        open = FALSE, id = "methodology",
        accordion_panel("How the score works", icon = bs_icon("calculator"),
                        method_html),
        accordion_panel("Arrakis · Dune", icon = bs_icon("sun"),
                        fam_pills("Arrakis")),
        accordion_panel("Middle-earth · LOTR", icon = bs_icon("tree"),
                        fam_pills("Middle-earth")),
        accordion_panel("Isla Nublar · Jurassic Park", icon = bs_icon("droplet"),
                        fam_pills("Isla Nublar"))
      ),
      div(class = "text-muted small mt-2",
          "Data: USDA PLANTS database ",
          popover(
            bs_icon("info-circle"),
            title = "About the data",
            HTML(paste0(meta$source, "<br><br>Built: ", meta$built_at,
                        "<br>Contact: tsgilbert@arizona.edu"))
          )
      )
    ),

    uiOutput("sel_summary"),
    uiOutput("kpis"),

    div(
      id = "chartcard",
      card(
        full_screen = TRUE,
        card_header(
          div(class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
              span("Flora match by world"),
              div(class = "metric-seg",
                  radioButtons("metric", NULL, inline = TRUE, selected = "raw",
                               choices = c("Raw" = "raw", "Fair share" = "fair"))
              )
          )
        ),
        card_body(girafeOutput("match_chart")),
        card_footer(
          div(class = "pim-chart-note mb-2", textOutput("metric_note")),
          div(class = "pim-caveat", caveat_html)
        )
      )
    ),

    card(
      full_screen = TRUE,
      card_header("Shared-species map"),
      card_body(plotOutput("distPlot", height = "400px")),
      card_footer(div(class = "pim-chart-note", chord_caption_html))
    )
  )
)


server <- function(input, output, session) {

  # auto-build the default view on load (never blank, no progressive-disclosure flash)
  shinyjs::delay(350, shinyjs::click("click_state"))

  # first-visit welcome modal, gated by localStorage (the head script reports it).
  # Delayed so it lands after the cold-start title card and the first render; we
  # mark it "seen" the moment it shows, so it never reappears in this browser.
  observeEvent(input$seen_welcome, {
    if (isFALSE(input$seen_welcome)) {
      shinyjs::delay(1200, {
        showModal(welcome_modal())
        session$sendCustomMessage("pim_mark_welcome", TRUE)
      })
    }
  }, once = TRUE)

  observeEvent(input$dismiss_welcome, removeModal())

  # selected states, available only after the first Create/Refresh click
  selected <- reactive({
    req(input$click_state)
    input$state %||% character(0)
  })

  # shared table feeding BOTH the chart and the KPI value boxes (computed once)
  match_tbl <- reactive({
    sel <- selected()
    if (length(sel) == 0) return(NULL)
    build_match_table(sel, biome_tally, biome_totals, state_biome_family, state_richness)
  })

  output$sel_summary <- renderUI({
    sel <- selected()
    if (length(sel) == 0)
      return(div(class = "pim-sel-summary", "Select states to compare."))
    div(class = "pim-sel-summary",
        sprintf("Comparing %d state%s:  %s", length(sel),
                if (length(sel) != 1) "s" else "", paste(sel, collapse = ", ")))
  })

  # three computed KPI value boxes: the leading state per world (honors the toggle)
  output$kpis <- renderUI({
    tbl <- match_tbl()
    if (is.null(tbl)) return(NULL)
    bp <- best_per_biome(tbl, input$metric)
    boxes <- lapply(.biome_order, function(m) {
      r <- bp[bp$Movie == m, ]
      bm <- BIOME_META[[m]]
      score <- if (input$metric == "fair")
        paste0(r$fair, "% of this world's flora")
      else
        paste0(formatC(r$n, big.mark = ",", format = "d"), " species")
      div(
        class = "pim-kpi",
        onclick = "document.getElementById('chartcard').scrollIntoView({behavior:'smooth',block:'start'});",
        value_box(
          title = paste0(m, " · ", bm$movie),
          value = r$State,
          showcase = bs_icon(bm$icon),
          theme = value_box_theme(bg = bm$soft, fg = bm$dark),
          p(class = "mb-0 small", score)
        )
      )
    })
    do.call(layout_columns, c(list(col_widths = breakpoints(xs = 12, sm = 4)), boxes))
  })

  output$metric_note <- renderText({
    if (input$metric == "fair")
      "Fair share: each state measured against the same national species pool per world, so big states don't win automatically."
    else
      "Raw counts: total species in each world's families — favors big, species-rich states. Switch to Fair share to level the field."
  })

  # interactive "flora match" chart (ggiraph)
  output$match_chart <- renderGirafe({
    on.exit(waiter_hide())  # hide the cold-start title card once the first chart is ready
    sel <- selected()
    if (length(sel) == 0) return(empty_girafe())
    tbl <- match_tbl()
    build_match_girafe(tbl, mode = input$metric)
  })

  # chord edges: biome edges (state<->movie) + state edges (state<->state)
  chord_data <- reactive({
    sel <- selected()
    if (length(sel) == 0) return(NULL)
    biome_edges <- biome_tally %>%
      filter(State %in% sel) %>% select(Movie, State, n)
    pair_edges <- state_pairs %>%
      filter(StateA %in% sel, StateB %in% sel) %>%
      transmute(Movie = StateA, State = StateB, n)
    bind_rows(biome_edges, pair_edges)
  })

  output$distPlot <- renderPlot({
    my_data <- chord_data()
    if (is.null(my_data) || nrow(my_data) == 0) {
      par(bg = "#F4EFE6", mar = c(0, 0, 0, 0)); plot.new()
      text(0.5, 0.5, "Select one or more states to see the shared-species map.",
           col = "#6E665A", cex = 1.15)
      return(invisible())
    }

    # single-hue parchment -> ink lightness ramp ordered by richness (CVD-safe)
    state_colors <- my_data %>%
      group_by(State) %>%
      summarise(total_n = sum(n), .groups = "drop") %>%
      arrange(total_n) %>%
      mutate(color = colorRampPalette(
        c("#E7D6B6", "#B7A98C", "#7A4B2B", "#3F2E1E"))(n()))
    state_grid_col <- setNames(state_colors$color, state_colors$State)

    # narrow screens: drop crowded sector names, keep grid + axis
    w <- session$clientData[["output_distPlot_width"]]
    track <- if (!is.null(w) && w < 600) c("grid", "axis") else c("name", "grid", "axis")

    par(mai = c(0.2, 0.2, 0.2, 0.2), bg = "#F4EFE6", mar = c(0, 0, 0, 0))
    circos.par(gap.after = 3)
    chordDiagram(
      my_data,
      annotationTrack = track,
      grid.border = NA,
      grid.col = c("Arrakis" = "#C9852A", "Middle-earth" = "#3F7A52",
                   "Isla Nublar" = "#2E8A99", state_grid_col),
      link.sort = TRUE, link.decreasing = TRUE,
      transparency = 0.25, link.border = NA,
      preAllocateTracks = .8
    )
    circos.clear()
  })

}

# Run the application
shinyApp(ui = ui, server = server)
