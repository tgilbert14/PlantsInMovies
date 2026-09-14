library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(tidyr)
library(circlize)
library(ggplot2)
library(ggiraph)
source("R/biomes.R")
source("R/charts.R")
source("R/cinema.R")
source("R/notebook.R")
biome_tally <- readRDS("data/biome_tally.rds")
biome_totals <- readRDS("data/biome_totals.rds")
state_biome_family <- readRDS("data/state_biome_family.rds")
state_richness <- readRDS("data/state_richness.rds")
state_pairs <- readRDS("data/state_pairs.rds")
meta <- readRDS("data/meta.rds")
APP_URL <- "https://019ecc91-3c6c-bee2-f824-0ea23fc60ac6.share.connect.posit.cloud/"
cinema_theme <- bs_theme(version = 5, bg = "#F3EDDD", fg = "#253028", primary = "#385741",
                        base_font = "system-ui, -apple-system, sans-serif", heading_font = "Georgia, serif",
                        "border-radius" = "0.2rem") |>
  bs_add_rules(sass::sass_file("www/cinema-v3.scss"))
ui <- page_fluid(
  title = "Plants in Movies · Botanical Cinema", theme = cinema_theme,
  tags$head(tags$meta(name = "description", content = "Explore three movie worlds through real USDA plant records. Compare states and discover the plant families behind each match."),
            tags$meta(property = "og:title", content = "Plants in Movies · A botanical cinema atlas"),
            tags$meta(property = "og:description", content = "Step into an illustrated botanical atlas. Explore three movie worlds through real plant records, then collect your discoveries."),
            tags$meta(property = "og:url", content = APP_URL), tags$meta(property = "og:type", content = "website"),
            tags$meta(property = "og:image", content = paste0(APP_URL, "cinema/share-v2.jpg")),
            tags$meta(property = "og:image:width", content = "1200"), tags$meta(property = "og:image:height", content = "800"),
            tags$meta(property = "og:image:type", content = "image/jpeg"),
            tags$meta(property = "og:image:alt", content = "Plants in Movies: antique botanical engravings of grasses, woodland leaves and ferns"),
            tags$meta(name = "twitter:card", content = "summary_large_image"),
            tags$link(rel = "preload", href = "cinema/atlas-v2.webp", as = "image"),
            tags$script(src = "cinema-v3.js", defer = NA)),
  tags$a(href = "#compare", class = "skip-link", "Skip to state comparison"),
  tags$noscript(div(class = "no-js", h2("Plants in Movies"),
     p("This interactive R/Shiny app needs JavaScript to compare plant records. Its three movie worlds use curated plant-family groups, not observed film flora."),
     tags$a(href = "https://github.com/tgilbert14/PlantsInMovies", "Read the source and data"))),
  tags$header(class = "cinema-top",
    div(class = "cinema-nav", tags$a(href = "https://desertdatalabs.com", class = "brand", "DESERT DATA LABS"),
        div(class = "nav-tools", tags$a(href = "#notebook", "Field notebook"), tags$a(href = "#about", "About the data"),
            tags$button(type = "button", id = "motion-control", `aria-pressed` = "false", "Pause motion"),
            input_dark_mode(id = "dark_mode", mode = "light"))),
    div(class = "atlas-arrival",
      tags$img(src = "cinema/atlas-v2.webp", class = "atlas-panorama", alt = "An imagined botanical landscape: golden desert grasses give way to woodland leaves and a lush fern forest.", width = 2172, height = 724, fetchpriority = "high"),
      div(class = "projector-light", `aria-hidden` = "true"),
      div(class = "atlas-legend", span("FIELD NOTES FROM IMAGINED WORLDS"), span("VOL. I / THE BOTANICAL EDITION")),
      div(class = "masthead",
        div(class = "masthead-copy", p(class = "eyebrow", "A NATURALIST GOES TO THE MOVIES"),
          h1("Plants in ", tags$em("Movies")),
          p(class = "intro-copy", "Explore the plants that echo three movie worlds. See which ones appear in your state’s records."),
          div(class = "arrival-actions", tags$a(href = "#compare", class = "atlas-cta", "Explore the plants", span(`aria-hidden`="true", "↘")),
              span(class = "arrival-note", "Three worlds. Real plant records."))),
        div(class = "atlas-seal", `aria-hidden` = "true", span("HERBARIUM"), strong("×"), span("CINEMATOGRAPH"))),
      div(class = "film-edge", `aria-hidden` = "true")),
    div(class = "reel-heading", span("CHOOSE YOUR FEATURE"), tags$button(type="button", id="next-world", "Turn the reel", span(`aria-hidden`="true", " ↻"))),
    world_buttons()
  ),
  tags$main(id = "compare", tabindex = "-1", class = "cinema-main",
    div(class="chapter-label", span("01 / CHOOSE YOUR PLACES"), span("Pick states to compare.")),
    div(class = "control-desk",
      div(class = "state-picker", selectizeInput("state", "Compare states & territories", choices = meta$states,
         selected = c("Arizona", "California", "Maine"), multiple = TRUE,
         options = list(placeholder = "Choose one or more places", plugins = list("remove_button")))),
      div(class = "metric-picker", radioButtons("metric", "Show matching records as", inline = TRUE,
          choices = c("Record count" = "raw", "National pool %" = "fair"), selected = "raw")),
      tags$button(type = "button", class = "reset-states", id = "reset-states", "Reset states")
    ),
    div(class = "selection-line", textOutput("sel_summary"), span(class = "connection-status", role = "status", "Connecting…")),
    div(class = "screening-table", uiOutput("world_scene"),
      div(class = "match-sheet", uiOutput("world_comparison"))),
    tags$section(class = "family-section", `aria-labelledby` = "family-heading",
      div(class = "section-heading", div(p(class = "eyebrow", "BEHIND THE MATCH"), h2(id = "family-heading", "Meet the supporting cast.")),
          p("Choose a plant family to see its part in the picture.")),
      div(class = "family-workbench", div(class = "family-selector", uiOutput("family_controls")),
          div(class = "family-sheet", tags$span(class="visually-hidden", role="status", textOutput("family_status", inline=TRUE)), uiOutput("family_detail")))),
    notebook_ui(),
    tags$section(class = "all-worlds-section", `aria-labelledby` = "all-worlds-heading",
      div(class = "section-heading", div(p(class = "eyebrow", "THE WIDER PICTURE"), h2(id = "all-worlds-heading", "Three worlds, side by side.")),
          p("The same states and measure, across every world.")),
      div(class = "plot-paper", girafeOutput("match_chart"), textOutput("metric_note")),
      tags$details(class = "data-details", tags$summary("Read the comparison as a table"), div(class="table-scroll", tabindex="0", role="region", `aria-label`="Comparison data table", tableOutput("match_table")))),
    tags$section(class = "connections-section", `aria-labelledby` = "connections-heading",
      div(class = "section-heading", div(p(class = "eyebrow", "SHARED ROOTS"), h2(id = "connections-heading", "Follow the connections.")),
          uiOutput("export_controls")),
      div(class = "connection-layout", div(class = "plot-paper", plotOutput("distPlot", height = "480px")),
        div(class = "connection-notes", h3("Plants cross borders."),
            p("Wider ribbons mean more shared plant records. World-to-state links use the curated families. State-to-state links use the full checklist."),
            p("Ribbon totals overlap, so they are not a count of unique plants across the whole map."),
            uiOutput("chord_key"),
            tags$details(class = "data-details", tags$summary("Read every connection"), div(class="table-scroll", tabindex="0", role="region", `aria-label`="Connection data table", tableOutput("chord_table"))))))
  ),
  tags$footer(id = "about", class = "cinema-footer",
    div(class = "footer-inner", div(class = "footer-about", p(class = "eyebrow", "THE SMALL PRINT"), h2("A little movie magic.\nReal plant records."),
      p("Each world is a hand-picked set of plant families inspired by its setting. A match does not mean a plant appeared in the film or would grow in that world.")),
      div(class = "footer-method", tags$details(tags$summary("How the counts work"),
        p("We count the unique USDA plant codes in each state’s list that belong to the chosen families. Some codes refer to a variety or subspecies, so plant records are not the same as species."),
        p("National pool % shows a state’s count as a share of the national total for those families. It does not account for state size or large plant families. The order of states stays the same.")),
      tags$details(tags$summary("Coverage & source"),
        p(paste0("The bundle contains ", meta$n_states, " state/territory checklists, including Puerto Rico. Rhode Island is absent from this source export. There are ", fmt(meta$n_species), " distinct USDA symbols across the full bundle.")),
        p(paste("Data prepared:", meta$built_at)),
        tags$a(href = "https://plants.usda.gov/", "USDA PLANTS database"), tags$br(),
        tags$a(href = "https://github.com/tgilbert14/PlantsInMovies", "Code & curated family lists")),
      p(class = "illustration-note", "Botanical plates are AI-generated artwork inspired by antique engravings, not a guide for identifying plants. This educational app is not affiliated with the USDA or any movie studio."))),
    div(class = "footer-bottom", span("Plants in Movies / Desert Data Labs / Tucson, AZ"),
       tags$a(href = "mailto:desertdatalabs@gmail.com?subject=Plants%20in%20Movies", "Get in touch"))
  )
)
server <- function(input, output, session) {
  selected <- reactive(intersect(input$state %||% character(), meta$states))
  world <- reactive(if (is.null(input$world) || !input$world %in% names(WORLD_STYLE)) "Arrakis" else input$world)
  observeEvent(input$reset_states, updateSelectizeInput(session, "state", selected = c("Arizona", "California", "Maine")))
  match_tbl <- reactive({
    if (!length(selected())) return(NULL)
    build_match_table(selected(), biome_tally, biome_totals, state_biome_family, state_richness)
  })
  family <- reactive({
    f <- input$family
    if (is.null(f) || !f %in% BIOME_FAMILIES[[world()]]) {
      c(Arrakis="Poaceae", `Middle-earth`="Asteraceae", `Isla Nublar`="Pinaceae")[[world()]]
    } else f
  })
  output$sel_summary <- renderText({
    if (!length(selected())) "Choose a state or territory to begin."
    else paste0("Comparing ", length(selected()), if(length(selected()) == 1) " place" else " places", " · ", world())
  })
  output$world_scene <- renderUI({
    w <- world(); st <- WORLD_STYLE[[w]]
    div(class = paste("world-scene", st$id), style = paste0("--scene-tone:", st$tone),
      div(class = "scene-topline", span("NOW EXPLORING"), span(BIOME_META[[w]]$movie)),
      h2(w), p(class = "scene-subtitle", st$title),
      div(class = "scene-specimen", `data-plate` = st$id,
          world_art(w), div(class = "specimen-lens", `aria-hidden` = "true"),
          span(class = "plate-number", `aria-hidden` = "true", paste0("FIG. 0", match(w,names(WORLD_STYLE))))),
      div(class = "lens-tools", tags$button(type="button", class="lens-toggle", `aria-pressed`="false", "Open specimen lens"),
          span("ILLUSTRATIVE PLATE / 2× DETAIL")),
      div(class = "lens-sliders", hidden=NA,
          tags$label("Move left or right", tags$input(type="range", min="0", max="100", value="50", class="lens-x", `aria-label`="Move left or right")),
          tags$label("Move up or down", tags$input(type="range", min="0", max="100", value="50", class="lens-y", `aria-label`="Move up or down"))),
      div(class = "scene-caption", span(paste(length(BIOME_FAMILIES[[w]]), "curated families")), span("BOTANICAL ILLUSTRATION")),
      p(class = "scene-description", st$description))
  })
  output$world_comparison <- renderUI({
    tbl <- match_tbl(); w <- world()
    if (is.null(tbl)) return(div(class="empty-state", h3("Choose a place to begin."),p("Choose a state or territory above to reveal its plant records.")))
    rows <- tbl[tbl$Movie == w, ]; rows <- rows[order(-rows$n, as.character(rows$State)), ]
    maxn <- max(rows$n, 1)
    tagList(div(class = "sheet-title", span(class = "eyebrow", "IN YOUR STATES"),
       h3(if (input$metric == "fair") "Share of the national pool" else "The plants in the picture")),
       p(class = "sheet-unit", if (input$metric == "fair") "Percent of all records in this world's curated pool" else "Distinct plant records in this world's families"),
       div(class = "state-results", tabindex="0", role="region", `aria-label`="World comparison results", lapply(seq_len(nrow(rows)), function(i) {
         r <- rows[i, ]; value <- if (input$metric == "fair") paste0(r$fair, "%") else fmt(r$n)
         width <- if (input$metric == "fair") r$fair else 100*r$n/maxn
         div(class = "state-result", div(class = "result-label", span(as.character(r$State)), strong(value)),
            div(class = "result-track", `aria-hidden` = "true", div(class = "result-fill", style = paste0("width:",width,"%;background:", BIOME_META[[w]]$color))))
       })),
       p(class = "pool-note", paste(fmt(biome_totals$pool_us[biome_totals$Movie == w]), "records in this world's curated national pool.")),
       tags$a(href = "#family-heading", class = "sheet-link", "Look inside the families ↓"))
  })
  output$family_controls <- renderUI({
    w <- world()
    tagList(p(class = "micro", paste(w, "· choose a family")),
      div(class = "family-buttons", lapply(BIOME_FAMILIES[[w]], function(f) {
        tags$button(type = "button", `data-family` = f, `aria-pressed` = if (f == isolate(family())) "true" else "false", f)
      })))
  })
  family_rows <- reactive({
    if (!length(selected())) return(NULL)
    counts <- state_biome_family |> filter(Movie == world(), Family == family(), State %in% selected()) |> select(State,n)
    data.frame(State=selected()) |> left_join(counts, by="State") |> mutate(n=replace_na(n,0L)) |>
      left_join(biome_tally |> filter(Movie == world()) |> select(State,total=n), by="State") |>
      mutate(total=replace_na(total,0L), percent=ifelse(total>0,round(100*n/pmax(total,1),1),0)) |>
      arrange(desc(n),State)
  })
  output$family_status <- renderText(paste(family(), "updated for", length(selected()), "places."))
  output$family_detail <- renderUI({
    rows <- family_rows()
    tagList(div(class = "family-detail-title", p(class = "eyebrow", "FAMILY CLOSE-UP"), h3(family())),
      p(paste("Its contribution to", world(), "in your selected places.")),
      if (is.null(rows)) p(class="empty-state", "Select a place above to see this family's contribution.") else
        div(class = "family-results", tabindex="0", role="region", `aria-label`="Family contribution results", lapply(seq_len(nrow(rows)), function(i) {
          r <- rows[i,]
          div(class="family-result", div(class="result-label", strong(r$State),span(paste(fmt(r$n),"records"))),
           div(class="family-track", `aria-hidden`="true", div(style=paste0("width:",r$percent,"%"))),
           p(paste0(r$percent,"% of this state's ",world()," count")))
        })),
      p(class="micro", "A zero means no matching record in this export, not proof of absence."),
      tags$button(type="button", id="collect-family", class="collect-family", `data-collect-world`=world(), `data-collect-family`=family(), disabled=if(is.null(rows)) NA else NULL, "Save this family", span(`aria-hidden`="true", " ↗")),
      tags$a(href="#notebook", class="notebook-jump", "View notebook ↓"),
      span(id="collect-feedback", class="collect-feedback", `aria-hidden`="true"))
  })
  notebook_server(input, output, session, world, family, family_rows)
  output$metric_note <- renderText({
    if (input$metric == "fair") "National pool % compares each state with the same national total for that world. It does not account for state size or large plant families."
    else "Counts can favor larger or richer checklists. Open a family above to see what contributes."
  })
  output$match_chart <- renderGirafe({
    if (is.null(match_tbl())) return(empty_girafe("Choose states above to compare their plant records."))
    narrow <- !is.null(session$clientData$output_match_chart_width) && session$clientData$output_match_chart_width < 650
    build_match_girafe(match_tbl(), mode=input$metric, width_svg=if(narrow) 5 else 10, stacked=narrow)
  })
  output$match_table <- renderTable({
    req(match_tbl()); match_tbl() |> transmute(State=as.character(State), World=Movie, Records=n, `National pool (%)`=fair)
  }, striped=TRUE, rownames=FALSE)
  chord_data <- reactive({
    if (!length(selected())) return(NULL)
    bind_rows(biome_tally |> filter(State %in% selected()) |> select(Movie,State,n),
       state_pairs |> filter(StateA %in% selected(),StateB %in% selected()) |> transmute(Movie=StateA,State=StateB,n))
  })
  output$distPlot <- renderPlot({
    e <- chord_data()
    # Large comparisons use an honest summary, with exact edges still available as a table.
    if(length(selected())>8) {par(bg="#F3EDDD",mar=c(1,1,1,1));plot.new();text(.5,.55,"Choose up to 8 places for a readable map.",cex=.95,col="#253028");text(.5,.44,"Read or save all connections with the table and CSV.",cex=.8,col="#485544")}
    else draw_cinema_chord(e, with_names=TRUE, show_axis=(session$clientData$output_distPlot_width %||% 700) >= 550)
  }, res=110)
  output$chord_key <- renderUI({
    if (!length(selected())) return(NULL)
    div(class="chord-key", lapply(names(BIOME_META),function(w) div(span(style=paste0("background:",BIOME_META[[w]]$color), `aria-hidden`="true"),w)))
  })
  output$chord_table <- renderTable({req(chord_data()); chord_data() |> transmute(From=Movie,To=State,`Shared records`=n)},striped=TRUE)
  output$export_controls <- renderUI({
    tagList(
      if (length(selected()) > 0 && length(selected()) <= 8)
        downloadButton("dl_chord", "Save connection map", class="export-button")
      else tags$button(type="button", disabled=NA, class="export-button",
                       if (!length(selected())) "Choose places to export" else "Map limited to 8 places"),
      if (length(selected())) downloadButton("dl_connections", "Save connections CSV", class="export-button"))
  })
  output$dl_connections <- downloadHandler(
    filename=function() paste0("plants-in-movies-", selection_slug(selected()), "-connections.csv"),
    content=function(file) {
      req(chord_data())
      write.csv(chord_data() |> transmute(
        From=Movie, To=State, SharedPlantRecords=n,
        ConnectionType=ifelse(Movie %in% names(BIOME_META), "World to state", "State to state"),
        Basis=ifelse(Movie %in% names(BIOME_META), "Curated movie-world families", "Full state checklists"),
        Source="USDA PLANTS export", BundleBuilt=meta$built_at),file,row.names=FALSE)
    })
  output$dl_chord <- downloadHandler(
    filename=function() paste0("plants-in-movies-", selection_slug(selected()), "-connections.png"),
    content=function(file) {
      png(file,width=1800,height=1800,res=180,bg="#F3EDDD");on.exit(dev.off())
      if(length(selected())>8) {par(bg="#F3EDDD");plot.new();text(.5,.55,"Choose up to 8 places for a readable connection map.",cex=.9,col="#253028")}
      else draw_cinema_chord(chord_data(),TRUE,"Plants in Movies · Shared plant records")
    })
}
shinyApp(ui,server)
