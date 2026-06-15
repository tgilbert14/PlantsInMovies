library(shiny)
library(shinycssloaders)
library(shinythemes)
library(shinyjs)
library(shinydashboard)
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

# Picker choices come straight from the data, so every option has data behind it
# (this drops Rhode Island, which had no rows, and adds Puerto Rico, which did).
picker_states <- meta$states

ui <- fluidPage(
  shinyjs::useShinyjs(),
  theme = shinytheme("cyborg"),
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    # let the interactive chart use the full width on small screens
    tags$style(HTML("#match_chart, #match_chart svg { max-width: 100%; }"))
  ),

  titlePanel(div(style = "color: white; font-size: 32px;",
    HTML("<strong>Which State's Flora Matches Each Movie World Best?</strong>"))),

  sidebarLayout(
    sidebarPanel(width = 3,

      box(
        div(style = "color: orange; font-size: 16px;", id = "select",
            HTML("Select <strong>state(s)</strong> to see how their plant species line
            up with each movie-themed biome &mdash; and how much flora the states
            share with one another!")),
        title = NULL, status = "primary", solidHeader = TRUE, width = NULL),
      br(),
      box(
        title = NULL, status = "warning", solidHeader = TRUE, width = NULL,
        selectizeInput("state", label = NULL,
                       choices = picker_states,
                       selected = c("Arizona", "California", "Maine"),  # non-blank default view
                       multiple = TRUE),
        actionButton(
          inputId = "click_state",
          label = "Create/Refresh",
          icon = icon("refresh"),
          width = "100%",
          class = "btn-warning"
        )
      ),
      br(),
      div(style = "color: #0072B2; font-size: 12px;", id = "start",
        HTML("<p><em>Species were pulled from the USDA plant database and filtered to
        include only those whose families matched the movie-themed biomes.</em></p>
        <p><strong>Dune (<em>Arrakis</em>)</strong> includes plant families associated
        with succulents, desert plants, grasses and drought-adapted species.</p>
        <p><strong>Lord of the Rings (<em>Middle-Earth</em>)</strong> includes cool
        forest and alpine plant families.</p>
        <p><strong>Jurassic Park (<em>Isla Nublar</em>)</strong> includes families
        that represent ancient groups such as ferns, conifers, and horsetails.</p>
        <p><em>Please contact tsgilbert@arizona.edu with questions or feedback!</em></p>")
      ),
      actionButton(
        inputId = "more_info",
        label = "Please tell me more!",
        icon = icon("info-circle"),
        width = "100%",
        class = "btn-info"
      )
    ),

    mainPanel(
      br(),
      verbatimTextOutput("sel_summary", placeholder = FALSE),

      # metric toggle (live; switches the bar chart's metric without re-selecting)
      div(id = "metric_wrap",
          style = "margin: 4px 0 2px 2px;",
          radioButtons(
            "metric", label = NULL, inline = TRUE, selected = "raw",
            choices = c("Raw species counts" = "raw",
                        "Fair share (size-adjusted)" = "fair")
          )
      ),

      shinycssloaders::withSpinner(
        girafeOutput("match_chart", width = "100%"),
        type = 6, size = 1, color = "#0072B2", color.background = "#151515"
      ),

      # honest methodology caveat
      div(id = "caveat",
          style = "color: #E8A33D; font-size: 13px; border-left: 3px solid #E8A33D;
                   padding: 6px 10px; margin: 8px 2px; background: rgba(232,163,61,0.06);",
          HTML("<strong>Read me:</strong> raw counts favor big, species-rich states and
          large plant families &mdash; e.g. <em>Asteraceae</em> (the daisy family, the
          largest on Earth) alone is ~65% of Arizona's &ldquo;Middle-earth&rdquo; score.
          Switch to <strong>Fair share</strong> to measure each state against the same
          national species pool per world, and <em>hover any bar</em> to see which
          families are doing the work. These biome groupings are a playful curation,
          not a phylogenetic claim.")
      ),

      br(),
      div(style = "color: #0072B2; font-size: 14px; margin-bottom: 4px;", id = "plot_head",
          HTML("<strong>Shared-species map</strong> &mdash; how the selected states
          overlap with each movie world and with each other:")),
      shinycssloaders::withSpinner(
        plotOutput("distPlot", height = "400px"),
        type = 6, size = 4, color = "#0072B2", color.background = "#009E73"
      ),
      div(style = "color: #0072B2; font-size: 14px;", id = "plot_info",
          HTML("Cord width represents the number of species shared between the
          state(s) and movie worlds. Following a cord from a movie biome
          (<em>e.g., Arrakis in black</em>) to a state shows how many species they
          share; cords between two states show species that occur in both."))
    )
  )
)


server <- function(input, output) {

  # progressive disclosure: hide explanation + chart chrome until first build
  to_hide <- c("start", "more_info", "caveat", "plot_head", "plot_info", "metric_wrap")
  for (id in to_hide) shinyjs::hide(id)

  observeEvent(input$click_state, {
    shinyjs::hide("select")
    for (id in to_hide) shinyjs::show(id)
  })

  # auto-build the default view on load so the app is never blank
  shinyjs::delay(350, shinyjs::click("click_state"))

  observeEvent(input$more_info, {
    showModal(modalDialog(
      title = HTML("<strong>Species Family Breakdown</strong>"),
      HTML('<p><strong>How the score works.</strong> For each state we count the unique
      plant species whose family belongs to a movie world\'s curated family list.
      <em>Raw species counts</em> show those totals; <em>Fair share</em> divides by the
      number of such species nationwide, so small and large states can be compared
      fairly (it removes the advantage big, species-rich states and giant plant
      families would otherwise have).</p>
      <p><strong>The Isla Nublar (Jurassic Park)</strong> families are focused on ferns,
      conifers, horsetails, and ancient groups: "Araucariaceae", "Aspleniaceae",
      "Blechnaceae", "Cupressaceae", "Cyatheaceae", "Cycadaceae", "Dennstaedtiaceae",
      "Dryopteridaceae", "Equisetaceae", "Ginkgoaceae", "Isoetaceae", "Marattiaceae",
      "Ophioglossaceae", "Osmundaceae", "Pinaceae", "Podocarpaceae", "Polypodiaceae",
      "Psilotaceae", "Pteridaceae", "Selaginellaceae", "Thelypteridaceae" and
      "Zamiaceae".</p>
      <p><strong>The Arrakis (Dune)</strong> families are focused on succulents, desert
      plants, grasses, and drought-adapted groups: "Agavaceae", "Aizoaceae",
      "Amaranthaceae", "Anacardiaceae", "Asparagaceae", "Brassicaceae", "Burseraceae",
      "Cactaceae", "Fouquieriaceae", "Frankeniaceae", "Poaceae", "Polygonaceae",
      "Tamaricaceae" and "Zygophyllaceae".</p>
      <p><strong>The Middle-Earth (LOTR)</strong> families are focused on cool forests
      and alpine plants: "Apiaceae", "Araliaceae", "Asteraceae", "Betulaceae",
      "Cornaceae", "Ericaceae", "Fagaceae", "Gentianaceae", "Hydrangeaceae",
      "Juglandaceae", "Primulaceae", "Ranunculaceae", "Rosaceae", "Salicaceae" and
      "Saxifragaceae".</p>'),
      easyClose = TRUE,
      footer = NULL
    ))
  })

  # selected states, available only after the first Create/Refresh click
  selected <- reactive({
    req(input$click_state, input$state)
    input$state
  })

  output$sel_summary <- renderText({
    sel <- selected()
    paste0("Comparing ", length(sel), " state", if (length(sel) != 1) "s" else "",
           ":  ", paste(sel, collapse = ", "))
  })

  # interactive "flora match" chart (ggiraph) -- replaces the old plotly gauges
  output$match_chart <- renderGirafe({
    sel <- selected()
    tbl <- build_match_table(sel, biome_tally, biome_totals,
                             state_biome_family, state_richness)
    build_match_girafe(tbl, mode = input$metric)
  })

  # chord edges: biome edges (state<->movie) + state edges (state<->state),
  # each a cheap filter on the precomputed bundle -- no per-click O(K^2) loop.
  chord_data <- reactive({
    sel <- selected()
    biome_edges <- biome_tally %>%
      filter(State %in% sel) %>%
      select(Movie, State, n)
    pair_edges <- state_pairs %>%
      filter(StateA %in% sel, StateB %in% sel) %>%
      transmute(Movie = StateA, State = StateB, n)
    bind_rows(biome_edges, pair_edges)
  })

  output$distPlot <- renderPlot({
    my_data <- chord_data()
    if (nrow(my_data) == 0) return(NULL)

    state_colors <- my_data %>%
      group_by(State) %>%
      summarise(total_n = sum(n), .groups = "drop") %>%
      arrange(desc(total_n)) %>%
      mutate(color = colorRampPalette(
        c("#0B04E0", "#333EAD", "#5C797A", "#84B346", "#ACED13"))(n()))
    state_grid_col <- setNames(state_colors$color, state_colors$State)

    par(mai = c(0.4, 0.4, 0.4, 0.4), bg = "gray90", mar = c(0, 0, 0, 0))
    chordDiagram(my_data,
                 annotationTrack = c("name", "grid", "axis"),
                 grid.border = "black",
                 grid.col = c("Arrakis" = "black",
                              "Middle-earth" = "#E67E22",
                              "Isla Nublar" = "#1ABC9C",
                              state_grid_col),
                 preAllocateTracks = .8)
    circos.clear()
  })

}

# Run the application
shinyApp(ui = ui, server = server)
